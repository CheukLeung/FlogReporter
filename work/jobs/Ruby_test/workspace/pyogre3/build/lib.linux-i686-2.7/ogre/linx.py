# ----------------------------------------------------------------
# linx.py
# ----------------------------------------------------------------
"""
LINX connection

This class implements the Linx protocol for communication with other
OSE nodes. Each instance of the class creates a Linx endpoint. The
endpoint is used to send/receive signals to/from other OSE processes

Note, the Linx kernel extension (linx.ko) must be installed on the host.
See aslo http://sourceforge.net/projects/linx
"""
import ctypes
import logging
import select
import struct

import ogre
import ogre.hexdump


# Private constants
_MinProtocolVersion = 0x02000001
_MaxMsgSize         = 65535

# Linx protocol
_AF_LINX    = 0x1D
_SOCK_DGRAM = 2

_IOCTL_VERSION   = 0x8004F40E
_IOCTL_PARAM_SET = 0x405CF40D
_IOCTL_PARAM_GET = 0x405CF40C
_IOCTL_DESTROY   = 0x405CF40A
_IOCTL_CREATE    = 0x405CF409
_IOCTL_HUNTNAME  = 0xC00CF408
_IOCTL_INFO      = 0xC008F407
_IOCTL_UNREGISTER_LINK_SUPERVISOR = 0xF406
_IOCTL_REGISTER_LINK_SUPERVISOR   = 0xF405
_IOCTL_DETACH    = 0x4004F404
_IOCTL_ATTACH    = 0xC010F403
_IOCTL_HUNT      = 0xC014F402
_IOCTL_SET_RECEIVE_FILTER = 0x400CF401
_IOCTL_MAGIC     = 0xF4

# Debug support
_log = logging.getLogger('ogre')


# Struct definitions for the Linx socket interface
class _LinxHuntname(ctypes.Structure):
    _fields_ = [ ('spid',    ctypes.c_uint),
                 ('namelen', ctypes.c_size_t),
                 ('name',    ctypes.c_char_p) ]

class _LinxHuntParam(ctypes.Structure):
    _fields_ = [ ('sigsize', ctypes.c_size_t),
                 ('sig',     ctypes.c_char_p),
                 ('pid',     ctypes.c_uint),
                 ('namelen', ctypes.c_size_t),
                 ('name',    ctypes.c_char_p) ]

class _linx_attach_param(ctypes.Structure):
    _fields_ = [ ('spid',    ctypes.c_uint),
                 ('sigsize', ctypes.c_size_t),
                 ('sig',     ctypes.c_char_p),
                 ('attref',  ctypes.c_uint) ]

class _linx_detach_param(ctypes.Structure):
    _fields_ = [ ('attref',  ctypes.c_uint) ]


class _linx_receive_filter_param(ctypes.Structure):
    _fields_ = [ ('pid',       ctypes.c_uint),
                 ('size',      ctypes.c_size_t),
                 ('sigselect', ctypes.POINTER(ctypes.c_uint)) ]


class _sockaddr(ctypes.Structure):
    _fields_ = [ ('family', ctypes.c_ushort),
                 ('spid',   ctypes.c_uint) ]

class _iovec(ctypes.Structure):
    _fields_ = [ ('iov_base',    ctypes.c_char_p),
                 ('iov_len',     ctypes.c_size_t) ]

class _cmsghdr(ctypes.Structure):
    _fields_ = [ ('cmsg_len',    ctypes.c_size_t),
                 ('cmsg_level',  ctypes.c_int),
                 ('cmsg_type',   ctypes.c_int) ]

class _cmsg(ctypes.Structure):
    _fields_ = [ ('header',  _cmsghdr),
                 ('body',    _linx_receive_filter_param) ]

class _msghdr(ctypes.Structure):
    _fields_ = [ ('msg_name',       ctypes.POINTER(_sockaddr)),
                 ('msg_namelen',    ctypes.c_int),
                 ('msg_iov',        ctypes.POINTER(_iovec)),
                 ('msg_iovlen',     ctypes.c_size_t),
                 ('msg_control',    ctypes.POINTER(_cmsg)),
                 ('msg_controllen', ctypes.c_size_t),
                 ('msg_flags',      ctypes.c_uint) ]


class _cmsg_send(ctypes.Structure):
    _fields_ = [ ('header',  _cmsghdr),
                 ('from_',   ctypes.c_uint) ]

class _msghdr_send(ctypes.Structure):
    _fields_ = [ ('msg_name',       ctypes.POINTER(_sockaddr)),
                 ('msg_namelen',    ctypes.c_int),
                 ('msg_iov',        ctypes.POINTER(_iovec)),
                 ('msg_iovlen',     ctypes.c_size_t),
                 ('msg_control',    ctypes.POINTER(_cmsg_send)),
                 ('msg_controllen', ctypes.c_size_t),
                 ('msg_flags',      ctypes.c_uint) ]


# ----------------------------------------------------------------
class Linx(object):
    """
    Instances of his class represents a LINX endpoint on the host.

    Public methods:
        hunt()    -- Hunt for a target process by name
        attach()  -- Start supervision of a target process
        detach()  -- Dtop supervision of a target process
        send()    -- Send a signal to a target process
        receive() -- Receive a signal
        pid()     -- Return the endpoint proxy pid

    Usage:
        >>> import ogre, signals
        >>> gw = ogre.create('linx', 'unit_test')
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
        gw.close()
    """

    def __init__(self, name):
        """Create a LINX endpoint. 

        Parameters:
            name -- the LINX endpoint name

        Usage:
            gw = ogre.Linx('test')
            ...
            gw.close()
        """
        global libc
        libc = ctypes.CDLL('libc.so.6')

        # LINX is only working on Linux, probably i686 (little endian)
        self.little_endian = True
        self.server_version = 0
        self.proxy_pid = 0
        self.socket = libc.socket(_AF_LINX, _SOCK_DGRAM, 0)
        if self.socket < 0:
            raise OSError()

        buf = ctypes.c_uint()
        ret = libc.ioctl(self.socket, _IOCTL_VERSION, ctypes.byref(buf))
        if ret < 0:
            raise OSError("ioctl ret %d" % ret)
        self.server_version = buf.value
        if self.server_version < _MinProtocolVersion:
            raise ogre.NotSupportedError("version %x(%x)" % (
               self.server_version, _MinProtocolVersion))

        buf = _LinxHuntname(47, len(name), name + '\0')
        ret = libc.ioctl(self.socket, _IOCTL_HUNTNAME, ctypes.byref(buf))
        if ret < 0:
            raise OSError("ioctl ret %d" % ret)
        self.proxy_pid = buf.spid
        _log.debug('LINX endpoint "%s" created, pid=%d' % (name,
                                                           self.proxy_pid))


    def __del__(self):
        """Delete the LINX connection."""
        self.close()


    def close(self):
        """Terminate the LINX connection"""
        if self.proxy_pid:
            _log.debug('close LINX endpoint, pid=%d' % (self.proxy_pid))
            self.proxy_pid = 0
        if self.socket:
            libc.close(self.socket)
            self.socket = None


    def pid(self):
        """Return the endpoint proxy pid."""
        return self.proxy_pid


    def hunt(self, name, hunt_sig = None):
        """Search for a process by name.

        When the process is found a signal is sent back to the calling
        process with signal number ogre.HUNT_SIG. If a hunt signal is
        specified, it is used instead

        Parameters:
            name      -- the process name
            hunt_sig  -- (optional) a signal to be sent back when
                         the specified process is found

        Usage:
            gw = ogre.Linx('test')
            gw.hunt('ogre_echo')
            pid = gw.receive().sender()
        """
        if hunt_sig:
            hunt_sig_str = struct.pack('L', hunt_sig.sigNo) + hunt_sig._to_string_buffer(self.little_endian)
            hunt_sig_len = len(hunt_sig_str)
        else:
            hunt_sig_str = None
            hunt_sig_len = 0

        _log.debug('hunt for %s' % name)

        args = _LinxHuntParam()
        args.sigsize = hunt_sig_len
        args.sig = hunt_sig_str
        args.pid = self.proxy_pid
        args.namelen = len(name)
        args.name = name + '\0'
        ret = libc.ioctl(self.socket, _IOCTL_HUNT, ctypes.byref(args))
        if ret < 0:
            raise OSError("ioctl ret %d" % ret)


    def attach(self, pid, attach_sig = None):
        """
        Attach to a remote process to detect if the process is
        terminated. The attach_signal is stored within linx endpoint
        until the process is terminated. If no signal is specified, the
        linx endpoint allocates a default signal with signal number
        ATTACH_SIG.

        Parameters:
            pid        -- the pid of the process to attach to
            attach_sig -- the signal to send if when pid dies (optional)

        Usage:
            gw.hunt('ogre_echo')
            pid = gw.receive().sender()
            ref = gw.attach(pid)
        """
        if attach_sig:
            attach_sig_str = struct.pack('L', attach_sig.sigNo) + attach_sig._to_string_buffer(self.little_endian)
            attach_sig_len = len(attach_sig_str)
        else:
            attach_sig_str = None
            attach_sig_len = 0

        _log.debug('attach to  %d' % pid)

        args = _linx_attach_param(pid, attach_sig_len, attach_sig_str)
        ret = libc.ioctl(self.socket, _IOCTL_ATTACH, ctypes.byref(args))
        if ret < 0:
            raise OSError("ioctl ret %d" % ret)

        return args.attref


    def detach(self, ref):
        """
        Remove a signal previously attached by the caller.

        Parameters:
            ref -- a reference returned by a previous attach()

        Usage:
            ref = gw.attach(pid)
            ...
            gw.detach(ref)
        """
        if self.proxy_pid == 0:
            return 0

        _log.debug('detach  %d' % ref)

        args = _linx_detach_param(ref)
        libc.ioctl(self.socket, _IOCTL_DETACH, ctypes.byref(args))


    def send(self, sig, pid, sender = 0):
        """Send an OSE signal to the specified process.

        Parameters:
            sig    -- the signal to send
            pid    -- the pid of the process the signal will be sent to
            sender -- the pid of the process specified as sender, default 0

        Usage:
            mysig = TestReq()
            mysig.a = 10
            mysig.b = 20
            gw.send(mysig, targetpid)
        """
        if sender:
            self._send_w_sender(sig, pid, sender)
        else:
            self._send_to(sig, pid)


    def receive(self, sig_sel=None, timeout=None):
        """Receive a signal.

        Sig_sel is a sequence of signal numbers to be received. The
        method returns when a signal matching any of the specified
        signal numbers is found. If the timeout expires None is
        returned.

        Parameters:
            sig_sel -- a sequence of signal numbers (default all_sig)
            timeout -- the timeout value in seconds (optional)

        Usage
            mysignal = gw.receive()            # receive any signal
            mysignal = gw.receive([MY_SIG])    # receive MY_SIG only
            mysignal = gw.receive(timeout=1.0) # wait max 1 second
        """
        if timeout:
            self._set_receive_filter(sig_sel)
            rfd, wfd, efd = select.select([self.socket], [], [], timeout)
            if not self.socket in rfd:
                return None     # timeout expired

        if sig_sel:
            return self._receive_signal(sig_sel)
        else:
            return self._receive_any_signal()


    def init_async_receive(self, sig_sel=None):
        """
        Initiate a non blocking receive operation. The signal is later
        retreived by a call to async_receive().

        Parameters:
            sig_sel -- a sequence of signal numbers

        Usage:
            gw.init_async_receive()
            signal = gw.async_receive()
            gw.cancel_async_receive()
        """
        self._set_receive_filter(sig_sel)


    def cancel_async_receive(self):
        """
        Cancel a async_receive operation started with a call to
        init_async_receive()
        """
        self._set_receive_filter([])
        return None


    def async_receive(self, sig_sel=None):
        """
        This methid is used for receiving signals in a non blocking
        mode. The receive operation is initiated with a call to
        init_async_receive().

        Parameters:
            sig_sel -- same as in init_async_receive

        Usage:
            gw.init_async_receive()
            fd = gw.get_blocking_object()
            (rfd, wdf, wfd) = select.select([fd], [], [])
            if fd in rfd:
                signal = gw.async_receive()
                ...
            gw.cancel_async_receive()
        """
        return self.receive(sig_sel)


    def get_blocking_object(self):
        """
        Returns a file descriptor that can be used in a select() call to
        wait for any signal from the linx endpoint.
        """
        return self.socket


    # Private methods ---

    def _filter_param(self, sig_sel):
        """
        Private method. Returns a receive_filter_param c-struct
        for the specified sigselect
        """
        if sig_sel is None:
            sig_sel = []
        no_of_sig = len(sig_sel)
        sig_sel_array = (ctypes.c_uint * (no_of_sig + 1))()
        sig_sel_array[0] = no_of_sig
        for i in range(no_of_sig):
            sig_sel_array[i + 1] = sig_sel[i] 

        return _linx_receive_filter_param(0, 
                                          ctypes.sizeof(sig_sel_array), 
                                          sig_sel_array)


    def _set_receive_filter(self, sig_sel):
        """
        Private method. Set the LINX receive filter. Only used for
        select()
        """
        if self.socket is None:
            raise ogre.ConnectionLostError()

        args = self._filter_param(sig_sel)
        ret = libc.ioctl(self.socket,
                         _IOCTL_SET_RECEIVE_FILTER,
                         ctypes.byref(args))
        if ret < 0:
            raise OSError("ioctl ret %d" % ret)


    def _send_w_sender(self, sig, pid, sender):
        """
        Private method. Sends an OSE signal to the specified process.
        uing sendmsg()
        """
        if self.socket is None:
            raise ogre.ConnectionLostError()

        sig_str = struct.pack('L', sig.sigNo) + sig._to_string_buffer(self.little_endian)
        sig_len = len(sig_str)
        if sig_len > _MaxMsgSize:
            raise ogre.NotSupportedError("signal len %d" % sig_len)

        if _log.isEnabledFor(logging.DEBUG):
            _log.debug('SEND:to=%d, length=%d\n%s' % (
                  pid, sig_len, ogre.hexdump.hexdump(sig_str, prefix='   ')))

        adr = _sockaddr(_AF_LINX, pid)

        iov = _iovec()
        iov.iov_base = ctypes.c_char_p(sig_str)
        iov.iov_len = sig_len

        cmsg = _cmsg_send()
        cmsg.header.cmsg_len = ctypes.sizeof(cmsg)
        cmsg.from_ = sender

        msg = _msghdr_send()
        msg.msg_name = ctypes.pointer(adr)
        msg.msg_namelen = ctypes.sizeof(adr)
        msg.msg_iov = ctypes.pointer(iov)
        msg.msg_iovlen =  1
        msg.msg_control = ctypes.pointer(cmsg)
        msg.msg_controllen = ctypes.sizeof(cmsg)
        msg.msg_flags = 0
        
        ret = libc.sendmsg(self.socket, ctypes.byref(msg), 0)
        if ret != sig_len:
            raise OSError("sendmsg ret %d" % ret)


    def _send_to(self, sig, pid):
        """
        Private method. Sends an OSE signal to the specified process. 
        """
        if self.socket is None:
            raise ogre.ConnectionLostError()

        sig_str = struct.pack('L', sig.sigNo) + sig._to_string_buffer(self.little_endian)
        sig_len = len(sig_str)
        if sig_len > _MaxMsgSize:
            raise ogre.NotSupportedError("signal len %d" % sig_len)

        if _log.isEnabledFor(logging.DEBUG):
            _log.debug('SEND:to=%d, length=%d\n%s' % (
                  pid, sig_len, ogre.hexdump.hexdump(sig_str, prefix='   ')))

        saddr = _sockaddr(_AF_LINX, pid)
        ret = libc.sendto(self.socket, sig_str, sig_len, 0, 
                          ctypes.byref(saddr), ctypes.sizeof(saddr))
        if ret != sig_len:
            raise OSError("ioctl ret %d" % ret)


    def _receive_signal(self, sig_sel):
        """ 
        Private method. Receive a signal from LINX. Only signals specified
        by sig_sel can be received. 
        """
        if self.socket is None:
            raise ogre.ConnectionLostError()

        buf = ctypes.create_string_buffer(_MaxMsgSize)
        adr = _sockaddr()

        iov = _iovec()
        iov.iov_base = ctypes.cast(buf, ctypes.c_char_p)
        iov.iov_len = ctypes.sizeof(buf)

        cmsg = _cmsg()
        cmsg.header.cmsg_len = ctypes.sizeof(cmsg)
        cmsg.body = self._filter_param(sig_sel)

        msg = _msghdr()
        msg.msg_name = ctypes.pointer(adr)
        msg.msg_namelen = ctypes.sizeof(adr)
        msg.msg_iov = ctypes.pointer(iov)
        msg.msg_iovlen =  1
        msg.msg_control = ctypes.pointer(cmsg)
        msg.msg_controllen = ctypes.sizeof(cmsg)
        msg.msg_flags = 0

        # Now at last, receive the message
        bytes = libc.recvmsg(self.socket, ctypes.byref(msg), 0)
        if bytes < 4:
            raise Exception("protocol error")

        if  _log.isEnabledFor(logging.DEBUG):
            sig = buf.raw[0:bytes]
            _log.debug('RECV:from=%d length=%d\n%s' % (
                  adr.spid, bytes, ogre.hexdump.hexdump(sig, prefix='   ')))

        # Create a signal object
        signo = struct.unpack('L', buf.raw[0:4])[0]
        sigobj = ogre.signal.Signal.instantiate(signo)
        sigobj._from_string_buffer(buf.raw[4:], bytes-4, self.little_endian)
        sigobj._assign_sender(adr.spid)
        return sigobj


    def _receive_any_signal(self):
        """
        Private method. Receives any signal from LINX.
        """
        if self.socket is None:
            raise ogre.ConnectionLostError()
        # return self._receive_signal([])

        buf = ctypes.create_string_buffer(_MaxMsgSize)
        buf_len = ctypes.sizeof(buf)
        adr = _sockaddr()
        adr_len = ctypes.c_size_t(ctypes.sizeof(adr))

        bytes = libc.recvfrom(self.socket, buf, buf_len, 0, 
                              ctypes.byref(adr), ctypes.byref(adr_len))
        if bytes < 4:
            raise Exception("protocol error")

        if  _log.isEnabledFor(logging.DEBUG):
            sig = buf.raw[0:bytes]
            _log.debug('RECV:from=%d length=%d\n%s' % (
                  adr.spid, bytes, ogre.hexdump.hexdump(sig, prefix='   ')))

        # Create a signal object
        signo = struct.unpack('L', buf.raw[0:4])[0]
        sigobj = ogre.signal.Signal.instantiate(signo)
        sigobj._from_string_buffer(buf.raw[4:], bytes-4, self.little_endian)
        sigobj._assign_sender(adr.spid)
        return sigobj


if __name__ == "__main__":
    import doctest
    doctest.testmod()

# End of file
