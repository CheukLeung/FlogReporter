# ----------------------------------------------------------------
# process.py
# ----------------------------------------------------------------
"""
This module contains the Process class that represents a target
process.

Classes:
    Process - Represents a normal process on target

Known subclasses:
    DspProcess - Represents a DSP process on target
    
"""
import select

import ogre


# ----------------------------------------------------------------
class Process(object):
    """
    This class represents a target process.

    An instance of this class hunt and optionally attach to a target
    process specified by name. A separate connection is created for
    each target process.

    The send() method sends signals to the target process and the
    receive() methods receive signals from the target process. The
    generator receive_any() can be used to receive signals from all
    instances.

    Public methods:
        send()        -- Send a signal to the target process.
        receive()     -- Receive a signal from the target process.
        receive_any() -- Recive a signal from many processes 
        pid()         -- Return target process pid
        close()       -- Detach and disconnect

    Methods to override:
        handle_hunt_ind()   -- Handle received hunt signal.
        handle_attach_ind() -- Handle received attach signal.

    Usage:
        >>> import ogre
        >>> URL = 'tcp://172.17.226.207:22001'
        >>>
        >>> proc = ogre.Process(URL, 'ogre_echo')
        >>> proc.send(ogre.Signal(1000))
        >>>
        >>> sig = proc.receive([1002], timeout=0.1)
        >>> print sig
        None
        >>> sig = proc.receive()
        >>> print sig.sigNo
        1000
        >>> proc.close()
    """

    def __init__(self, url, name, pid = None, supervise = True):
        """Constructor.
        
        Creates a connection to a target process. If no target process
        pid is given the class will automatically hunt for the process
        name.

        Parameters:
            url       -- connection url (tcp://172.17.226.207:22001)
            name      -- the target process name
            pid       -- the target process pid (if known)
            supervise -- attach to the target process (default True)

        Usage:
            >>> import ogre
            >>> proc = ogre.Process('tcp://172.17.226.207:22001', 'ogre_echo')
            >>> proc.send(ogre.Signal(1000))
            >>> proc.close()
        """
        self.conn = None
        self.fd = None
        self.name = name
        self.target_pid = pid
        self.supervise = supervise
        self.attach_ref = None

        self.conn = ogre.create(url, name + '_proxy')
        self.fd = self.conn.get_blocking_object()

        if self.target_pid is None:
            self.conn.hunt(self.name)
        elif self.supervise and self.attach_ref == None:
            self.attach_ref = self.conn.attach(self.target_pid)


    def __del__(self):
        self.close()


    def __str__(self):
        return "Process %s" % (self.name)


    def pid(self):
        """Return the target process pid"""
        return self.target_pid


    def close(self):
        """Detach and disconnect."""
        if self.attach_ref:
            self.conn.detach(self.attach_ref)
            self.attach_ref = None
        if self.conn:
            self.conn.close()


    def send(self, sig, sender = 0):
        """Send a signal to the target process.

        The signal Subclass of ogre.Signal

        Parameters:
            sig    -- signal to send
            sender -- optional sender pid
        """
        if self.target_pid is None:
            hunt_sig = self.conn.receive([ogre.HUNT_SIG])
            self.handle_hunt_ind(hunt_sig)
        return self.conn.send(sig, self.target_pid, sender)


    def receive(self, sig_sel = None, timeout = None):
        """Receive a signal from the target process.

        Also handles any received hunt and attach signals. sig_sel is
        an array of signal numbers to receive. If sig_sel is not
        specified or an empty list all signal numbers will be
        received.

        Returns the received signal or None if no signal has been
        received before the timeout expires.

        Parameters:
            sig_sel -- a sequence of signal numbers (default = any_sig)
            timeout -- the timeout value in seconds (optional)
        """
        if sig_sel:
            sigselect = sig_sel + [ogre.HUNT_SIG, ogre.ATTACH_SIG] 
        else:
            sigselect = []

        while True:
            sig = self.conn.receive(sigselect, timeout)
            if sig:
                if self._handle_sig(sig):
                    continue
            return sig


    @classmethod
    def receive_any(cls, proc_list, timeout = None):
        """Receive signals from any of the specified Processes.

        Generator. Return a tuple with the receiving process and the
        received signal. If no signal has been received before the
        timeout expires the generator terminates.

        Parameters:
            proc_list -- list of Process objects to receive from
            timeout   -- the timeout value in seconds (optional)

        Usage:
            >>> import ogre
            >>> url = 'tcp://172.17.226.207:22001'
            >>> p1 = ogre.Process(url, 'proc1')
            >>> p2 = ogre.Process(url, 'ogre_echo')
            >>> p3 = ogre.Process(url, 'proc3')
            >>>
            >>> p2.send(ogre.Signal(1000))
            >>>
            >>> for proc, sig in ogre.Process.receive_any([p1, p2, p3], 2.0):
            ...     print proc, sig.sigNo
            Process ogre_echo 1000

        """
        fd_list = [ proc.conn.get_blocking_object() for proc in proc_list ]

        # Start async read from all processes
        for proc in proc_list:
            proc.conn.init_async_receive()

        # Generator main loop. Loop until timeout expires
        while True:
            (rfd, wdf, wfd) = select.select(fd_list, [], [], timeout)
            if not rfd:
                # The timeout has expired
                break

            # yield all received signals
            for fd in rfd:
                proc = proc_list[fd_list.index(fd)] 
                sig = proc.conn.async_receive()
                if not proc._handle_sig(sig):
                    yield (proc, sig)
                proc.conn.init_async_receive()
            
        # Cancel async read from all processes
        for proc in proc_list:
            sig = proc.conn.cancel_async_receive()
            if sig:
                if not proc._handle_sig(sig):
                    yield (proc, sig)


    # --- Signal handlers

    def _handle_sig(self, sig):
        """Handler for recived signal

        Handle any received hunt or attach signals. Return True if
        the signal is handled.
        """
        if sig.sigNo == ogre.HUNT_SIG:
            self.handle_hunt_ind(sig)
            return True
        elif sig.sigNo == ogre.ATTACH_SIG:
            self.handle_attach_ind(sig)
            return True
        return False
        

    def handle_hunt_ind(self, sig):
        """Handler for received hunt signal.
        
        Save the sender pid (the target process pid) and attach to the
        target process if supervise mode. Override in subclasses if you
        want to do anything more.
        """
        self.target_pid = sig.sender()
        if self.supervise and self.attach_ref == None:
            self.attach_ref = self.conn.attach(self.target_pid)


    def handle_attach_ind(self, sig):
        """Handler for received attach signal.
        
        Hunt again for the target process name if in supervise
        mode. Override in subclasses if you want to do anything more.
        """
        if sig.sender() != self.target_pid:
            raise Exception("attach signal from wrong process")

        self.target_pid = None
        self.attach_ref = None
        if self.supervise:
            self.conn.hunt(self.name)


    # Context manager support
    
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
        

# ----------------------------------------------------------------
if __name__ == "__main__":
    import doctest
    doctest.testmod()

# End of file
