#!/bin/env python
"""
monitor.py

Description:
  This program displays the Trace & Error log of a Cello Target on the
  screen and optionally saves the log in a file. This is an example of
  how to use Ogre for Python

Usage: monitor.py [options] [<linkhandler> ...]

Options:
  --version             show program's version number and exit
  -h, --help            show this help message and exit
  -r, --rel             present time stamps using relative times
  -q, --quiet           don't write logs to stdout
  -c CONFIG, --config=CONFIG
                        read configuration from CONFIG
  -f FILE, --file=FILE  write logs to FILE

Configuration:
  Default configuration (can be changed by using a custom
  configuration file):

  te: (T&E logs from target)
    Log everything to stdout using ABS format. Can be changed by the
    -r, -q and -f options

  mon: (The monitor itself)
    Log level INFO to stdout using LOG format
    
  ogre: (OSE Gateway)
    Log level INFO to stdout using LOG format
"""
from __future__ import with_statement
import logging
import logging.config
import optparse
import os
import sys

import ogre
import te_log


# Default log formats for monitor and ogre logs
LOG_FORMAT = "[%(levelname)s:%(message)s]"

# Default log format for absolute times
ABS_FORMAT = "[%(asctime)s] %(threadName)s %(filename)s:%(lineno)d %(levelname)s:%(message)s"

# Default log format for relative times
REL_FORMAT = "[%(relativeCreated)s] %(threadName)s %(filename)s:%(lineno)d %(levelname)s:%(message)s"

# T&E log levels
TE_LEVEL = 100
GROUP_NAME = [
  "CHECK",
  "ERROR",
  "ENTER",
  "RETURN",
  "INFO",
  "TRACE1",
  "TRACE2",
  "TRACE3",
  "TRACE4",
  "TRACE5",
  "TRACE6",
  "TRACE7",
  "TRACE8",
  "TRACE9", 
  "STATE CHANGE",
  "BUS SEND",
  "BUS RECEIVE",
  "REC SIG",
  "SEND SIG",
  "PARAM",
  "RESERVED1",
  "RESERVED2",
  "RESERVED3",
  "RESERVED4",
  "RESERVED5",
  "RESERVED6",
  "RESERVED7",
  "RESERVED8",
  "USER1",
  "USER2",
  "USER3",
  "USER4"
]


# Loggers
log = logging.getLogger()
log_te = logging.getLogger('te')

# ----------------------------------------------------------------
def cstring(buf, offset):
    """Convert a null terminated c-string to a python string"""
    j = buf.index('\0', offset)
    return buf[offset:j]

# ----------------------------------------------------------------
def hunt_path(linkhandler):
    """Return a valid hunt path to a T&E log process"""
    path = "%s/Sys_OMCSF_teLogMain" % (linkhandler)
    return path.lstrip('/')

# ----------------------------------------------------------------
class HuntInd(ogre.Signal):
    "The hunt indication signal."

    SIGNO = 9990

    def __init__(self, hunt_id = 0):
        ogre.Signal.__init__(self, self.SIGNO)
        self.hunt_id = hunt_id
        
    def serialize(self, writer, tag=None):
        writer.writeU32(self.hunt_id)

    def unserialize(self, reader, tag=None):
        self.hunt_id = reader.readU32()

ogre.Signal.register(HuntInd.SIGNO, HuntInd)


# ----------------------------------------------------------------
class TeLog(object):
    """
    Instances of this class represent one T&E log process on the
    target. 
    """

    def __init__(self, conn, name, hunt_id):
        self.conn = conn
        self.name = name
        self.hunt_id = hunt_id
        self.ref = None
        self.tick_length = None
        log.info('Hunting for %s' % (self.name))
        self.conn.hunt(self.name, HuntInd(self.hunt_id))
        
    def handle_hunt_ind(self, sig):
        self.ref = self.conn.attach(sig.sender())
        self.conn.send(te_log.OMCSF_logMonitorConnectReqS(), sig.sender())

    def handle_attach_ind(self, sig):
        log.warning("Lost contact with T&E %s" % (self.name))
        log.info('Hunting for %s' % (self.name))
        self.conn.hunt(self.name, HuntInd(self.hunt_id))

    def handle_connect_cfm(self, sig):
        self.tick_length = sig.tickLength
        if sig.result:
            log.info("Connected to %s" % (self.name))
        else:
            log.error("Connection rejected by T&E %s" % (self.name))
            self.detach()

    def handle_log_monitor_ind(self, sig):
        if sig.acknowledge:
            self.conn.send(te_log.OMCSF_logMonitorAckIndS(), sig.sender())
        self.handle_log(sig.relTimeStamp, sig.logData)
        
    def handle_log_read_ind(self, sig):
        if sig.acknowledge:
            self.conn.send(te_log.OMCSF_logReadAckIndS(), sig.sender())
        self.handle_log(sig.relTimeStamp, sig.logData)
        
    def detach(self):
        if self.ref:
            self.conn.detach(self.ref)
            self.ref = None

    def filter_log(self, log_data):
        # Override in subclasses to filter logs
        return True
    
    def handle_log(self, time_stamp, log_data):
        if not self.filter_log(log_data):
            return
        if time_stamp.ticks_ul < log_data.absTimeTick:
            ticks = time_stamp.ticks_ul + (0xffffffff - log_data.absTimeTick)
        else:
            ticks = time_stamp.ticks_ul - log_data.absTimeTick

        sec = (ticks * (self.tick_length / 1000)) / 1000 + log_data.absTimeSec
        ms  = (ticks * (self.tick_length / 1000)) % 1000
        rel = time_stamp.ticks_ul * self.tick_length + time_stamp.usecs_ul

        # Create a log record
        record = logging.LogRecord(
            name='te',
            level=log_data.group + TE_LEVEL,
            pathname=cstring(log_data.data, log_data.fileNamePos),
            lineno=log_data.lineNo,
            msg=cstring(log_data.data, log_data.msgPos),
            args=None,
            exc_info=None,
            func=None)

        # Add more info to the log record
        record.created = int(sec)
        record.msecs = ms
        record.threadName = cstring(log_data.data, log_data.procNamePos)
        record.relativeCreated = rel / 1000000.0
        log_te.handle(record)

        
# ----------------------------------------------------------------      
def main_loop(conn, args):
    """Monitor main receive loop.

    Create a TeLog object for each linkhandler specified on the
    command line. The dictionary pid_peer maps betwwen a target pid
    and the corresponding TeLog object.
    """
    peers = [ TeLog(conn, hunt_path(arg), i) for i, arg in enumerate(args) ]
    pid_peer = dict()    

    try:
        while True:
            sig = conn.receive()
            sender_pid = sig.sender()

            # Handle hunt replies
            if sig.sigNo == HuntInd.SIGNO:
                peer = peers[sig.hunt_id]
                pid_peer[sender_pid] = peer
                peer.handle_hunt_ind(sig)
                continue

            # Handle all other signals
            peer = pid_peer[sender_pid]
            if sig.sigNo == ogre.ATTACH_SIG:
                peer.handle_attach_ind(sig)
            elif sig.sigNo == te_log.OMCSF_logMonitorConnectCfmS.SIGNO:
                peer.handle_connect_cfm(sig)
            elif sig.sigNo == te_log.OMCSF_logMonitorIndS.SIGNO:
                peer.handle_log_monitor_ind(sig)
            elif sig.sigNo == te_log.OMCSF_logReadIndS.SIGNO:
                peer.handle_log_read_ind(sig)
            else:
                log.error("Unknown signal:\n%s" % sig)
    finally:
        for peer in peers:
            peer.detach()


# ----------------------------------------------------------------      
def init_logger(opts):
    """Initiate the logging module.
    """
    logging.basicConfig(format=LOG_FORMAT, level=logging.INFO,
                        stream=sys.stdout)
    log_te.propagate = 0
    
    # Init log levels
    lvl = TE_LEVEL
    for level_name in GROUP_NAME:
        logging.addLevelName(lvl, level_name)
        lvl += 1

    # Read a logger configuration file if any specified
    if opts.config:
        logging.config.fileConfig(opts.config)

    if opts.rel:
        te_formatter = logging.Formatter(REL_FORMAT)
    else:
        te_formatter = logging.Formatter(ABS_FORMAT)

    if not opts.quiet and not opts.config:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(te_formatter)
        log_te.addHandler(handler)

    if opts.file:
        handler = logging.FileHandler(opts.file)
        handler.setFormatter(te_formatter)
        log_te.addHandler(handler)

    
# ----------------------------------------------------------------      
def main():
    """Monitor main function.

    Parse the command line and open a connection to the target system.
    """
    parser = optparse.OptionParser("usage: %prog [options] [<linkhandler> ...]",
                              version="%prog 0.1")
    parser.add_option('-r', '--rel', action="store_true", dest="rel",
                 help="present time stamps using relative times")
    parser.add_option('-q', '--quiet', action="store_true", dest="quiet",
                 help="don't write logs to stdout")
    parser.add_option('-c', '--config', dest="config",
                 help="read configuration from CONFIG")
    parser.add_option('-f', '--file', dest="file",
                 help="write logs to FILE")

    # Parse the command line
    opts, args = parser.parse_args()
    if len(args) < 1:
        args.append('/')  # Default linkhandler

    # Init
    init_logger(opts)
    url = os.environ['OSEGWD_URL'] 

    # Run, ... and restart if connection lost
    while True:
        try:
            with ogre.create(url, "pymonitor") as conn:
                main_loop(conn, args)
        except ogre.ConnectionLostError:
            log.warning("Lost contact with node. Reconnecting...")
        except KeyboardInterrupt:
            log.info("Keyboard interrupt")
            break

    
# ----------------------------------------------------------------      
if __name__ == '__main__':
    main()

# End of file
