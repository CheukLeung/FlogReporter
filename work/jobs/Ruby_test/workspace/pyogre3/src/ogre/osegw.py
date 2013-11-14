# ----------------------------------------------------------------
# osegw.py
# ----------------------------------------------------------------
"""
OSE Gateway connection

This class implements the OSE Gateway protocol for communication with
the OSE Gateway server on a target node. Each instance of the class
creates a proxy process in the gateway server. The proxy process is
used to send/receive signals to/from other OSE processes on the target
node.
"""

# Hello Axel's world! 

import logging
import socket
import select
import struct
import time
import sys

import ogre
import ogre.hexdump


# Private constants
_PROTOCOL_VERSION      = 100

# Payload types
_PLT_InterfaceRequest  = 1
_PLT_InterfaceReply    = 2
_PLT_LoginRequest      = 3         # Not used
_PLT_ChallengeResponse = 4         # Not used
_PLT_ChallengeReply    = 5         # Not used
_PLT_LoginReply        = 6         # Not used
_PLT_CreateRequest     = 7
_PLT_CreateReply       = 8
_PLT_DestroyRequest    = 9
_PLT_DestroyReply      = 10
_PLT_SendRequest       = 11
_PLT_SendReply         = 12
_PLT_ReceiveRequest    = 13
_PLT_ReceiveReply      = 14
_PLT_HuntRequest       = 15
_PLT_HuntReply         = 16
_PLT_AttachRequest     = 17
_PLT_AttachReply       = 18
_PLT_DetachRequest     = 19
_PLT_DetachReply       = 20

# Server interface flags
_SFL_LittleEndian = 0x00000001
_SFL_UseAuthent   = 0x00000002

# Timeouts in seconds
_LINK_SUPERVISON_TIMEOUT = 8.0
_KEEP_ALIVE_PERIOD       = 4.0

# Debug support
_log = logging.getLogger('ogre')

# 
_PAYLOAD_TYPE = {
     0: "0",
     1: "InterfaceRequest",
     2: "InterfaceReply",
     3: "LoginRequest",
     4: "ChallengeResponse",
     5: "ChallengeReply",
     6: "LoginReply",
     7: "CreateRequest",
     8: "CreateReply",
     9: "DestroyRequest",
    10: "DestroyReply",
    11: "SendRequest",
    12: "SendReply",
    13: "ReceiveRequest",
    14: "ReceiveReply",
    15: "HuntRequest",
    16: "HuntReply",
    17: "AttachRequest",
    18: "AttachReply",
    19: "DetachRequest",
    20: "DetachReply",
    21: "21"
    }


# ----------------------------------------------------------------
class Osegw(object):
    """
    Instances of his class represents an OSE Gateway connection. Create
    an instance for each gateway server you want to comunicate with.

    Public methods:
        hunt()    -- Hunt for a target process by name
        attach()  -- Start supervision of a target process
        detach()  -- Dtop supervision of a target process
        send()    -- Send a signal to a target process
        receive() -- Receive a signal
        pid()     -- Return the proxy pid

    Usage:
        >>> import ogre, signals
        >>> gw = ogre.create('tcp://172.17.226.207:22001', 'unit_test')
        >>> gw.hunt('ogre_echo')
        >>> pid = gw.receive().sender()

        Send a signal to the target process
        >>> sig = signals.SyncReq()
        >>> sig.t1 = 47
        >>> gw.send(sig, pid)

        Receive the reply signal
        >>> reply = gw.receive()
        >>> print reply.t1
        47
        >>> gw.close()
    """

    def __init__(self, url, name):
        """Constructor.
        
        Create a OSE proxy process on the target and establish a
        connection with the process.

        Parameters:
            url   -- the gateway server URL, format: 'tcp://<host>:<port>'
            name  -- the OSE proxy process name

        Usage:
            >>> import ogre
            >>> gw = ogre.Osegw('tcp://172.17.226.201:22001', 'test')
            >>> gw.close()
        """
        self.server_version = 0
        self.server_flags = 0
        self.little_endian = False
        self.proxy_pid = 0
        self.max_signal_size = 0xffff
        self.payload_types = (_PLT_InterfaceRequest, )

        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.connect(self._parse_url(url))

        self._interface_check()
        if self.server_flags &  _SFL_UseAuthent:
            raise NotImplementedError()

        self._create(name)


    def _create(self, name):
        """Create a proxy process on target.

        This method is called from the constructor and should not
        be called by the user.

        Parameters:
            name    -- the proxy process name
        """
        user = 0
        request = struct.pack('!L%dsx' % len(name), user, name)

        self._send_msg(_PLT_CreateRequest, request)
        reply = self._receive_msg(_PLT_CreateReply)

        (status, pid, max_sigsize) = struct.unpack('!LLL', reply)
        if status:
            raise ogre.ServerError("error %d from gateway server" % status)
        self.proxy_pid = pid
        self.max_signal_size = max_sigsize


    def __del__(self):
        """
        Delete the target proxy process and disconnect.
        """
        self.close()


    def close(self):
        """Disconnect and close the connection.
        """
        status = 0
        if self.socket:
            if self.proxy_pid:
                try:
                    request = struct.pack('!L', self.proxy_pid)
                    self._send_msg(_PLT_DestroyRequest, request)
                    reply = self._receive_msg(_PLT_DestroyReply)
                    status = struct.unpack('!L', reply)[0]
                except ogre.ConnectionLostError:
                    pass

            self.proxy_pid = 0
            self.socket.close()
            self.socket = None

            if status:
                raise ogre.ServerError("error %d from gateway server" % status)


    def pid(self):
        """Return the target proxy process pid.
        """
        return self.proxy_pid


    def hunt(self, name, hunt_sig=None):
        """Hunt target process by name.
        
        Searche for a process by name. When the process is found a
        signal is sent back to the calling process with signal number
        ogre.HUNT_SIG. If a hunt signal is specified, it is used instead.

        Parameters:
            name      -- the process name
            hunt_sig  -- (optional) a signal to be sent back when
                         the specified process is found

        Usage:
            >>> import ogre
            >>> gw = ogre.Osegw('tcp://172.17.226.207:22001', 'test')
            >>> gw.hunt('ogre_echo')
            >>> pid = gw.receive().sender()
        """
        if hunt_sig:
            hunt_sig_str = hunt_sig._to_string_buffer(self.little_endian)
            hunt_sig_len = len(hunt_sig_str) + 4 # Include sigNo
            hunt_sig_signo = hunt_sig.sigNo
        else:
            hunt_sig_str = b""
            hunt_sig_len = 4
            hunt_sig_signo = ogre.HUNT_SIG

        request = struct.pack('!LLLLL%dsx' % len(name),
                              0,
                              0,
                              len(name) + 1,
                              hunt_sig_len,
                              hunt_sig_signo,
                              name)
        request += hunt_sig_str

        self._send_msg(_PLT_HuntRequest, request)
        reply = self._receive_msg(_PLT_HuntReply)
        (status, pid) = struct.unpack('!LL', reply)
        if status:
            raise ogre.ServerError("error %d from gateway server" % status)


    def attach(self, pid, attach_sig=None):
        """Supervise a target process.

        Attach to a target process to detect if the process is
        terminated. The attach_signal is stored within gateway server
        until the process is terminated. If no signal is specified,
        the gateway server allocates a default signal with signal
        number ATTACH_SIG.

        Parameters:
            pid        -- the pid of the process to attach to
            attach_sig -- the signal to send if when pid dies (optional)

        Usage:
            >>> import ogre
            >>> gw = ogre.Osegw('tcp://172.17.226.207:22001', 'test')
            >>> gw.hunt('ogre_echo')
            >>> pid = gw.receive().sender()
            >>> ref = gw.attach(pid)
        """
        if attach_sig:
            attach_sig_str = attach_sig._to_string_buffer(self.little_endian)
            attach_sig_len = len(attach_sig_str) + 4 # Include sigNo
            attach_sig_signo = attach_sig.sigNo
        else:
            attach_sig_str = b""
            attach_sig_len = 0
            attach_sig_signo = 0

        request = struct.pack('!LLL',
                              pid,
                              attach_sig_len,
                              attach_sig_signo)
        request += attach_sig_str

        self._send_msg(_PLT_AttachRequest, request)
        reply = self._receive_msg(_PLT_AttachReply)

        (status, ref) = struct.unpack('!LL', reply)
        if status:
            raise ogre.ServerError("error %d from gateway server" % status)
        return ref


    def detach(self, ref):
        """Cancel supervision of a target process.
        
        Removes a signal previously attached by the caller.

        Parameters:
            ref   -- a reference returned by a previous attach()

        Usage:
            ref = gw.attach(pid)
            ...
            gw.detach(ref)
        """
        if self.socket:
            try:
                request = struct.pack('!L', ref)
                self._send_msg(_PLT_DetachRequest, request)
                self._receive_msg(_PLT_DetachReply)
            except ogre.ConnectionLostError:
                pass


    def send(self, sig, pid, sender = 0):
        """Send an OSE signal to the specified process. 

        Parameters:
            sig    -- the signal to send
            pid    -- the pid of the process the signal will be sent to
            sender -- the pid of the process specified as sender, default 0

        Usage:
            >>> import ogre,signals
            >>> gw = ogre.create('tcp://172.17.226.207:22001', 'unit_test')
            >>> gw.hunt('ogre_echo')
            >>> pid = gw.receive().sender()
            >>>
            >>> mysig = signals.SyncReq()
            >>> mysig.t1 = 10
            >>> mysig.t2 = 20
            >>> gw.send(mysig, pid)
        """

        sig_str = sig._to_string_buffer(self.little_endian)
        sig_len = len(sig_str) + 4
        if sig_len > self.max_signal_size:
            raise ogre.NotSupportedError("signal length > %d" %
                                          (self.max_signal_size))

        request = struct.pack('!LLLL',
                              sender,
                              pid,
                              sig_len,
                              sig.sigNo)
        request += sig_str

        self._send_msg(_PLT_SendRequest, request)
        reply = self._receive_msg(_PLT_SendReply)

        status = struct.unpack('!L', reply)[0]
        if status:
            raise ogre.ServerError("error %d from gateway server" % status)


    def receive(self, sig_sel=None, timeout=None):
        """Receive a signal.
        
        Receive a signal from the signal queue. Sig_sel is a sequence
        of signal numbers to be received. The method returns when a
        signal matching any of the specified signal numbers is found. If
        the timeout expires None is returned.

        Parameters:
            sig_sel -- a sequence of signal numbers (default: any sig)
            timeout -- the timeout value in seconds (optional)

        Usage:
            mysignal = gw.receive()            # receive any signal
            mysignal = gw.receive([MY_SIG])    # receive MY_SIG only
            mysignal = gw.receive(timeout=1.0) # wait max 1 second
        """
        tmo = _KEEP_ALIVE_PERIOD

        if timeout is None:
            while True:
                self._send_receive_request(sig_sel, tmo)
                sig = self._receive_signal(tmo + _LINK_SUPERVISON_TIMEOUT)
                if sig is not None:
                    return sig

        else:
            stoptime = time.time() + timeout
            while True:
                if timeout < 3.0:
                    tmo = timeout
                self._send_receive_request(sig_sel, tmo)
                sig = self._receive_signal(tmo + _LINK_SUPERVISON_TIMEOUT)
                if sig is not None:
                    return sig
                timeout = stoptime - time.time()
                if timeout < 0.0:
                    return None


    def init_async_receive(self, sig_sel=None):
        """
        Initiate a non blocking receive operation. The signal is later
        retreived by a call to async_receive().

        Parameters:
            sig_sel -- a sequence of signal numbers (default all signals)

        Usage:
            See async_receive()
        """
        self._send_receive_request(sig_sel, None)


    def cancel_async_receive(self):
        """Cancel async receive.
        
        Cancel a async_receive operation started by
        init_async_receive(). Returns None, or a signal in case the
        server received a signal before the cancel request was
        received by the server.
        """
        request = struct.pack('!LL', 0xffffffff, 0)
        self._send_msg(_PLT_ReceiveRequest, request)

        sig = self._receive_signal(_LINK_SUPERVISON_TIMEOUT)
        if sig:
            # Receive the cancel reply message also
            self._receive_signal(_LINK_SUPERVISON_TIMEOUT)
        return sig
    

    def async_receive(self, sig_sel=None):
        """
        This methid is used for receiving signals in a non blocking
        mode. The receive operation is initiated with a call to
        init_async_receive().

        Parameters:
            sig_sel -- a sequence of signal numbers (default all signals)
                       same as in init_async_receive

        Usage:
            >>> import ogre
            >>> gw = ogre.Osegw('tcp://172.17.226.207:22001', 'test')
            >>> fd = gw.get_blocking_object()
            >>> 
            >>> gw.init_async_receive()
            >>> (rfd, wfd, efd) = select.select([fd], [], [], 0.2)
            >>> if fd in rfd:
            ...     signal = gw.async_receive()
            ... else:
            ...     signal = gw.cancel_async_receive()
        """
        return self._receive_signal(None)


    def get_blocking_object(self):
        """Return socket object.
        
        Returns a file descriptor that can be used in a select() call to
        wait for any signal from the gateway server.
        """
        return self.socket


    # Context manager support
    
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
        

    # Private methods ---

    def _interface_check(self):
        """
        Private method. Sends a InterfaceRequest message to the
        server. The reply from the server contains server version,
        server flags and a list of supported message.
        """
        flags = 0
        if sys.byteorder == 'little':
            flags |= _SFL_LittleEndian
        request = struct.pack('!LL', _PROTOCOL_VERSION, flags)

        self._send_msg(_PLT_InterfaceRequest, request)
        reply = self._receive_msg(_PLT_InterfaceReply)

        (status, version, flags, types_len) = struct.unpack(
            '!LLLL', reply[0:16])
        if status:
            raise ogre.ServerError("error %d from gateway server" % status)

        self.server_version = version
        self.server_flags = flags
        if (flags & _SFL_LittleEndian == 0):
           self.little_endian = False
        else:
           self.little_endian = True
#        self.little_endian = flags & _SFL_LittleEndian
        self.payload_types = struct.unpack('!%dL' % types_len, reply[16:])


    def _send_receive_request(self, sig_sel, timeout):
        """Private method. timeout in seconds"""
        if timeout is not None:
            ms = int(timeout * 1000)
        else:
            ms = 0xffffffff

        if sig_sel is None:
            sig_sel = []
        no_of_sigs = len(sig_sel)
        request = struct.pack('!LLL%dL' % no_of_sigs, ms, no_of_sigs + 1,
                              no_of_sigs, *sig_sel)
        self._send_msg(_PLT_ReceiveRequest, request)


    def _receive_signal(self, timeout):
        """Private method"""
        reply = self._receive_msg(_PLT_ReceiveReply, timeout)

        (status, sender, receiver, siglen, signo) = struct.unpack(
           '!LLLLL', reply[0:20])
        if status:
            raise RuntimeError("reply status %d" % (status))
        if siglen == 0:
            return None

        assert(receiver == self.proxy_pid)
        payload = reply[20:]              # Skip sigNo
        siglen -= 4                       # Skip sigNo
#       if (siglen != len(payload)):
#          _log.warning('wrong message size %d (expected %d)' % (
#             len(payload), siglen))

        sigobj = ogre.Signal.instantiate(signo)
        sigobj._from_string_buffer(payload, siglen, self.little_endian)
        sigobj._assign_sender(sender)
        return sigobj


    def _send_msg(self, request_type, request):
        """
        Private method. Sends an OSEGW message to the socket.
        """
        if self.socket is None:
            raise ogre.ConnectionLostError()

        if not request_type in self.payload_types:
            raise ogre.NotSupportedError("request type %d" % (request_type))

        if _log.isEnabledFor(logging.DEBUG):
            _log.debug('SEND:%s: length=%d\n%s' % (
               _PAYLOAD_TYPE[request_type], len(request),
               ogre.hexdump.hexdump(request, prefix='   ')))

        header = struct.pack('!LL', request_type, len(request))
        self.socket.send(header + request)


    def _receive_msg(self, reply_type, timeout=_LINK_SUPERVISON_TIMEOUT):
        """
        Private method. Receive an OSEGW message from the socket. If no
        message is received within the specified timeout period an
        exception is raised.
        """
        if self.socket is None:
            raise ogre.ConnectionLostError()

        header = self._recv(8, timeout)
        (type_id, length) = struct.unpack('!LL', header)
        reply = self._recv(length, _LINK_SUPERVISON_TIMEOUT)

        if  _log.isEnabledFor(logging.DEBUG):
            _log.debug('RECV:%s: length=%d\n%s' % (
               _PAYLOAD_TYPE[type_id], length,
               ogre.hexdump.hexdump(reply, prefix='   ')))

        if type_id != reply_type:
            raise Exception("wrong reply type %d(%d)" % (type_id, reply_type))
        return reply


    def _recv(self, bytes_left, timeout):
        """
        Private method. Receive the specified number of bytes from the
        socket. If no bytes are received during the timeout an exception
        is raised.
        """
        msg = b""
        while bytes_left > 0:
            rfd, wfd, efd = select.select([self.socket], [], [self.socket],
                                          timeout)
            if not self.socket in rfd:
                self.socket.close()
                self.socket = None
                raise ogre.ConnectionLostError()
            chunk = self.socket.recv(bytes_left)
            bytes = len(chunk)
            if bytes == 0:
                self.socket.close()
                self.socket = None
                raise ogre.ConnectionLostError()
            bytes_left -= bytes
            msg += chunk
        return msg


    def _parse_url(self, url):
        """Private method"""
        if not url.startswith('tcp://'):
            raise Exception("malformed URL: %s: (protocol)" % url)
        addr = url[6:].split(':')
        if not addr[0]:
            raise Exception("malformed URL: %s: (host)" % url)
        if not addr[1]:
            raise Exception("malformed URL: %s: (port)" % url)

        host = addr[0]
        port = int(addr[1])
        return (host, port)


# ----------------------------------------------------------------
if __name__ == "__main__":
    import doctest
    doctest.testmod()

# End of file
