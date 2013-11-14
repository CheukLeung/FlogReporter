"""
observer.py - Observer example program.

Shows how the ogre send and receive functions can be observed by
installing a observer callback function.
"""

from __future__ import with_statement
import ogre

URL = 'tcp://172.17.226.207:22001'

# The observer
def observer(f):
    event = f.__name__
    def notify(*arg):
        result = f(*arg)
        if event == 'send':
            print "CALLBACK %s %s" % (event, arg[0])
        elif event == 'receive':
            print "CALLBACK %s %s" % (event, result)
    return notify


# A main program with a process object to observe. The program sends a
# signal to the echo_proc and receives the reply signal.
with ogre.Process(URL, 'ogre_echo') as proc:

    # Register observers
    proc.receive = observer(proc.receive)
    proc.send    = observer(proc.send)

    sig = ogre.Signal(1234)
    proc.send(sig)
    proc.receive()

# End of file
