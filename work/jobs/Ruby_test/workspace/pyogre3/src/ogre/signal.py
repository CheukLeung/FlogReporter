#----------------------------------------------------------------
# signal.py
#----------------------------------------------------------------
"""
Classes for defining OSE signals.

Classes:
    Signal        -- Base class for signals
    Struct        -- Base class for struct in signals
    Array         -- Array in signals
    UnknownSignal -- A signal definition for a unknown signal
    
"""
import io

import ogre.big_endian
import ogre.little_endian

IND = "    "

# ----------------------------------------------------------------
class Array(list):
    """Array in a signal.
    
    The only purpose of this class is to provide a nice __str__()
    function.
    """
##     def __str__(self):
##         s = '[ '
##         for element in self:
##             s += "%s " % (element)
##         s += '] '
##         return s

    def __str__(self):
        return self.to_string()

    def to_string(self, indent = 0):
        if len(self) > 0 and hasattr(self[0], 'to_string'):
            s = '[\n'
            for element in self:
                s += "%s%s\n" % ((IND * (indent + 1)), element.to_string(indent + 1))
            s += '%s]' % (IND * indent)
        else:
            s = '[ '
            for element in self:
                s += "%s " % (element)
            s += ']'
        return s


# ----------------------------------------------------------------
class Struct(object):
    """
    Base class for structs in a signal. Create a subclass for each
    struct in a signal.
    """

    def serialize(self, writer, tag=None):
        "Override in subclasses with any data."
        pass

    def unserialize(self, reader, tag=None):
        "Override in subclasses with any data."
        pass

##     def __str__(self):
##         s = '{ '
##         for (attr, value)  in self.__dict__.items():
##             if not attr.startswith('_'):
##                 s += "%s=%s " % (attr, value)
##         s += '}'
##         return s

    def __str__(self):
        return self.to_string()

    def to_string(self, indent=0):
        s = '{\n'
        for attr in self.attributes():
            value = getattr(self, attr)
            if hasattr(value, 'to_string'):
                s += "%s%s: %s\n" % (IND*(indent + 1), attr, value.to_string(indent + 1))
            else:
                s += "%s%s: %s\n" % (IND*(indent + 1), attr, value)
        s += '%s}' % (IND * indent)
        return s

##     def __eq__(self, other):
##         "Two struct are identical if all attributes are equal."
##         if other is None:
##             return False
##         if len(self.__dict__) != len(other.__dict__):
##             return False
##         for (attr, value)  in self.__dict__.items():
##             if not value == other.__dict__[attr]:
##                 return False
##         return True

    def __eq__(self, other):
        "Two structs are identical if all attributes are equal."
        my_attributes = self.attributes()
        if other is None:
            return False
        if sorted(my_attributes) != sorted(other.attributes()):
            return False
        return all([getattr(other, attr) == getattr(self, attr)
                    for attr in my_attributes ])

    def attributes(self):
        """Returns a list off attribute names."""
        try:
            return self.ATTR_LIST
        except AttributeError:
            return [ attr for attr in self.__dict__ if not attr.startswith('_') ]
        

# ----------------------------------------------------------------
class Signal(Struct):
    """Base class for OSE Signals.

    Create a subclass for each signal you want to send or receive form
    OGRE.  If the signal contains any data the subclass must define a
    serialize() and a unserialize() method.

    Usage:
        class SyncSig(ogre.Signal):
            SIGNO = 10

            def __init__(self):
                Signal.__init__(self, self.SIGNO)
                self.a = 0
                self.b = StructB()

            def serialize(self, abi):
                abi.writeU32(self.a)
                self.b.serialize(abi)

            def unserialize(self, abi):
                self.a = abi.readU32()
                self.b.unserialize(abi)
    """

    signal_dict = dict()

    def __init__(self, sigNo):
        """Constructor.

        Parameters:
            sigNo -- the signal number
        """
        Struct.__init__(self)
        self.sigNo = sigNo
        self._sender = 0

##     def __str__(self):
##         """Return a human readable string representation of the signal."""
##         return "<OSESIG %s(sigNo=%d): %s>" % (self.__class__.__name__,
##                                               self.sigNo,
##                                               Struct.__str__(self))

    def __str__(self):
        """Return a human readable string representation of the signal."""
        return "OSESIG: %s: %s" % (self.__class__.__name__, self.to_string())

    def sender(self):
        """Return the sender pid of the signal.

        Return 0 if the signal has not been received.
        """
        return self._sender


    # Private methods --- called from connections and Process.py

    def _assign_sender(self, sender):
        """Set sender pid."""
        self._sender = sender

    def _to_string_buffer(self, le_byte_order):
        """Convert the signal to a byte buffer."""
        stream = io.BytesIO()
        if le_byte_order:
            self.serialize(ogre.little_endian.ByteBufferWriter(stream))
        else:
            self.serialize(ogre.big_endian.ByteBufferWriter(stream))
        return stream.getvalue()

    def _from_string_buffer(self, buf, buflen, le_byte_order):
        """Initialize the signal from a byte buffer."""
        if le_byte_order:
            reader = ogre.little_endian.ByteBufferReader(io.BytesIO(buf), buflen)
        else:
            reader = ogre.big_endian.ByteBufferReader(io.BytesIO(buf), buflen)
        self.unserialize(reader)

    # Class methods --- signal factory 

    @classmethod
    def register(cls, sigNo, signal):
        """Register a signal.
        
        Adds signal class into list of signals known by the system.
        When signal is received the system will use this information
        to automatically create and initialize the corresponding
        signal object.

        Parameters:
            sigNo  -- the signal number
            signal -- the signal class
        """
        if not isinstance(sigNo, int):
            raise TypeError("Parameter 'sigNo' must be integer")

        if not issubclass(signal, Signal):
            raise TypeError("Parameter 'signal' must be instance of Signal")

        if sigNo in cls.signal_dict:
            raise Exception("Duplicate registration of sigNo %d" % sigNo)

        cls.signal_dict[sigNo] = signal

    @classmethod
    def instantiate(cls, sigNo):
        """Create a signal from a signal number.
        
        Creates a new object with signal number ``sigNo``. If the
        signal number is not registered previously by calling
        register() then an object of class ``UnknownSignal`` is
        created.

        Parameters:
            sigNo -- number of the signal to be instantiated
        """
        if sigNo in cls.signal_dict:
            sig = cls.signal_dict[sigNo]()
            sig.sigNo = sigNo
            return sig
        else:
            return UnknownSignal(sigNo)


# ----------------------------------------------------------------
class UnknownSignal(Signal):
    """
    This signal is returned if Process receives a signal with a not
    registered signal number.
    """
    ATTR_LIST = [ 'sigNo' ]

    def __init__(self, sigNo):
        Signal.__init__(self, sigNo)
        self.buffer = None
    
    def serialize(self, writer, tag=None):
        if self.buffer:
            writer.write_byte_string(self.buffer)

    def unserialize(self, reader, tag=None):
        self.buffer = reader.read_byte_string(reader.length())


# End of file
