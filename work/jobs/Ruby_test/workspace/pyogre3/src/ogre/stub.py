# ----------------------------------------------------------------
# stub.py
# ----------------------------------------------------------------
"""
Base class for stubs simulating target processes on host.
"""
import threading
import logging

import ogre.factory


_log = logging.getLogger('ogre')


# ----------------------------------------------------------------
class Stub(threading.Thread):
    """
    Base class for host processes simulating a target process. Each
    instance of this class creates a python thread and a connection
    to a proxy process. Signals sent to the proxy process are
    handled by the python thread.

    Subclasses must implement the main() method, which is the pyton
    thread main loop.

    Usage:
        >>> import ogre, signals
        >>> url = 'tcp://172.17.226.207:22001'

        Define a stub process that echo all received signals
        >>> class EchoStub(ogre.Stub):
        ...     def main(self):
        ...         for i in range(1):
        ...             sig = self.conn.receive()
        ...             self.conn.send(sig, sig.sender())
        
        Start the stub process
        >>> stub = EchoStub(url, "echo_proc")

        Send a SyncReq signal to the echo process
        >>> proc = ogre.Process(url, "echo_proc")
        >>> proc.send(signals.SyncReq())
        >>> reply = proc.receive()
        >>> print reply.t1
        0
    """

    def __init__(self, url, name):
        """
        Create and start both a proxy process on target and a local
        python thread. The python thread main loop is defined by the
        subclass.

        Parameters:
            - url   = gateway server URL 'tcp://<host>:<port>'
            - name  = proxy process name
        """
        threading.Thread.__init__(self, name=name)
        self.name = name
        self.conn = ogre.factory.create(url, name)
        self.start()

    def pid(self):
        """Returns the proxy process pid"""
        return self.conn.pid()

    def run(self):
        """Thread main"""
        _log.info('Stub %s started' % (self.name))
        try:
            self.main()
        finally:
            _log.info('Stub %s terminated' % (self.name))
            self.conn.close()

    def main(self):
        """Stub thread main loop. Override in subclasses."""
        raise Exception("You must override main() in subclasses")
    

# ----------------------------------------------------------------
if __name__ == "__main__":
    import doctest
    doctest.testmod()

# End of file
