#!/bin/env python
"""
monitor2.py

Description:
  This program displays the Trace & Error log of a Cello Target on the
  screen and optionally saves the log in a file. This monitor is
  implemented with the ogre.Process class.

Usage: monitor2.py [options] [<linkhandler> ...]

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

log = logging.getLogger()
log_te = logging.getLogger('te')

# ----------------------------------------------------------------
def cstring(buf, offset):
    """Converts a null terminated c-string to a python string"""
    j = buf.index('\0', offset)
    return buf[offset:j]

# ----------------------------------------------------------------
def hunt_path(linkhandler):
    """Returns a valid hunt path to a T&E log process"""
    path = "%s/Sys_OMCSF_teLogMain" % (linkhandler)
    return path.lstrip('/')

# ----------------------------------------------------------------
class TeProcess(ogre.Process):
    """
    Instances of this class represent one T&E log process on the
    target. 
    """

    def __init__(self, url, name):
        ogre.Process.__init__(self, url, name, supervise = True)
        self.tick_length = None
        log.info('Hunting for %s' % (self.name))
        
    def handle_hunt_ind(self, sig):
        ogre.Process.handle_hunt_ind(self, sig)
        self.send(te_log.OMCSF_logMonitorConnectReqS())

    def handle_attach_ind(self, sig):
        ogre.Process.handle_attach_ind(self, sig)
        log.warning("Lost contact with T&E %s" % (self.name))
        log.info('Hunting for %s' % (self.name))

    def handle_connect_cfm(self, sig):
        self.tick_length = sig.tickLength
        if not sig.result:
            raise Exception("Connection rejected by T&E")
        log.info("Connected to %s" % (self.name))

    def handle_log_monitor_ind(self, sig):
        if sig.acknowledge:
            self.send(te_log.OMCSF_logMonitorAckIndS())
        self.handle_log(sig.relTimeStamp, sig.logData)
        
    def handle_log_read_ind(self, sig):
        if sig.acknowledge:
            self.send(te_log.OMCSF_logReadAckIndS())
        self.handle_log(sig.relTimeStamp, sig.logData)
        
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
def main_loop(url, args):
    """Monitor main loop.
    
    Hunt for each linkhandler specified on the command line and start
    the main loop.
    """
    peers = [ TeProcess(url, hunt_path(arg)) for arg in args ]

    try:
        while True:
            # Use a timeout value of 10 seconds for link supervision
            for peer, sig in TeProcess.receive_any(peers, 10.0):
                if sig.sigNo == te_log.OMCSF_logMonitorConnectCfmS.SIGNO:
                    peer.handle_connect_cfm(sig)
                elif sig.sigNo == te_log.OMCSF_logMonitorIndS.SIGNO:
                    peer.handle_log_monitor_ind(sig)
                elif sig.sigNo == te_log.OMCSF_logReadIndS.SIGNO:
                    peer.handle_log_read_ind(sig)
                else:
                    log.error("Unknown signal:\n%s" % sig)
                
    finally:
        for peer in peers:
            peer.close()

    
# ----------------------------------------------------------------      
def init_logger(opts):
    """
    Initiate the logging module.
    """
    logging.basicConfig(format=LOG_FORMAT, level=logging.INFO,
                        stream=sys.stdout)
    log_te.propagate = 0
    
    # Init log levels
    lvl = TE_LEVEL
    for level_name in GROUP_NAME:
        logging.addLevelName(lvl, level_name)
        lvl += 1

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
    parser = optparse.OptionParser("usage: %prog [options] [<linkhandler name> ...]",
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
            main_loop(url, args)
        except ogre.ConnectionLostError:
            log.warning("Lost contact with node. Reconnecting...")
        except KeyboardInterrupt:
            log.info("Keyboard interrupt")
            break

# ----------------------------------------------------------------      
if __name__ == '__main__':
    main()

# End of file
