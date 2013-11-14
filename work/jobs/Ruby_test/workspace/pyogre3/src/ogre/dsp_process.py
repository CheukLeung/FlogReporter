# ----------------------------------------------------------------
# dsp_process.py
# ----------------------------------------------------------------
"""
This module contains a DspProcess class and the signals required for
communication with DSP process through a server on the BP.
"""
import ogre


# ----------------------------------------------------------------
class _AttachReq(ogre.Signal):
    SIGNO = 74501
    def __init__(self):
        ogre.Signal.__init__(self, self.SIGNO)

class _AttachRsp(ogre.Signal):
    SIGNO = 74502
    def __init__(self):
        ogre.Signal.__init__(self, self.SIGNO)

class _LookupReq(ogre.Signal):
    SIGNO = 74517

    def __init__(self, name):
        ogre.Signal.__init__(self, self.SIGNO)
        self.name = name

    def serialize(self, writer):
        writer.string(self.name, len(self.name))

class _LookupRsp(ogre.Signal):
    SIGNO = 74518

    def __init__(self):
        ogre.Signal.__init__(self, self.SIGNO)
        self.pid = None

    def unserialize(self, reader):
        self.pid = reader.readU32()

class _BigSig(ogre.Signal):
    SIGNO = 74500

    def __init__(self, dsp_pid, sig):
        ogre.Signal.__init__(self, self.SIGNO)
        self.dsp_pid = dsp_pid
        self.sig = sig

    def serialize(self, writer):
        writer.writeU32(self.dsp_pid)
        writer.writeU32(self.sig.sigNo)
        self.sig.serialize(writer)

# Register the incomming signals
ogre.Signal.register(_AttachRsp.SIGNO, _AttachRsp)
ogre.Signal.register(_LookupRsp.SIGNO, _LookupRsp)


# ----------------------------------------------------------------
class DspProcess(ogre.Process):
    """
    This class represents a process in a DSP.

    The comunication with the DSP process must pass through a server
    process on the BP. This class extends the Process class and adds
    the handling of the BP server process.
    """

    def __init__(self, url, name, server_name, server_pid = None):
        """
        Creates a connection with a target process on a DSP. The name or
        pid of a BP process (the dedicated_server) must be provided to
        be able to lookup the pid of DSP process name.

        Parameters:
            - url         = connection url (tcp://172.17.226.207:22001)
            - name        = the DSP process name
            - server_name = name of the BP_server
            - server_pid  = optional pid of BP_server

        Usage:
            >>> import ogre
            >>> proc = ogre.DspProcess('tcp://172.17.226.207:22001',
            ...                        'ogre_echo',
            ...                        '001700/ds')
            >>> proc.send(ogre.Signal(1000))
        """
        ogre.Process.__init__(self, url, server_name, server_pid)
        self.dsp_name = name
        self.dsp_pid = None


    def pid(self):
        """Returns the DSP process pid"""
        return self.dsp_pid


    def send(self, sig, sender = 0):
        """
        Sends a signal to the DSP process over the dedicated server.

        Parameters:
            - sig    = signal to send. Subclass of ogre.Signal
            - sender = optional sender pid

        Usage:
            >>> import ogre
            >>> proc = ogre.DspProcess('tcp://172.17.226.207:22001',
            ...                        'ogre_echo',
            ...                        '000700/server')
            >>> sig = ogre.Signal(1234)
            >>> proc.send(sig)
        """
        if not self.target_pid or not self.dsp_pid:
            hunt_sig = self.conn.receive([ogre.HUNT_SIG])
            self.handle_hunt_ind(hunt_sig)

        big_sig = _BigSig(self.dsp_pid, sig)
        return self.conn.send(big_sig, self.target_pid, sender)


    def __str__(self):
        return "DSP Process %s" % (self.dsp_name)


    # --- Signal handlers

    def handle_hunt_ind(self, sig):
        """
        Attach to the BP server process and lookup the DSP pid.
        """
        ogre.Process.handle_hunt_ind(self, sig)

        # Attach to the BP server process
        self.conn.send(_AttachReq(), self.target_pid)
        self.conn.receive([_AttachRsp.SIGNO])

        # Ask the server process to lookup the DSP
        if not self.dsp_pid:
            self.conn.send(_LookupReq(self.dsp_name), self.target_pid)
            self.dsp_pid = self.conn.receive([_LookupRsp.SIGNO]).pid
            if self.dsp_pid == 0:
                raise ogre.ServerError("DSP '%s' not found" % self.dsp_name)


# ----------------------------------------------------------------
if __name__ == "__main__":
    import doctest
    doctest.testmod()

# End of file
