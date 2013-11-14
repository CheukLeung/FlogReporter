# ----------------------------------------------------------------
# big_endian.py - Big-endian byte buffer reader and writer.
# ----------------------------------------------------------------

"""
Stream-like interface for constructing and parsing C structures
for big-endian targets
"""
from struct import pack, unpack

import ogre.signal


# ----------------------------------------------------------------
class ByteBufferReader(object):
    #__slots__ = ['s', 'streamsize']


    def __init__(self, stream, streamsize):
        self.s = stream
        self.streamsize = streamsize

    def length(self):
        return self.streamsize

    def align(self, wordlen):
        alignment = self.s.tell() % wordlen
        if alignment != 0:
            padbytes = wordlen - alignment
            self.s.read(padbytes)

    def pad(self, padbytes):
        if padbytes != 0:
            self.s.read(padbytes)

    def seek(self, pos):
        self.s.seek(pos)
        
    # --- readers
    
    def readS8(self):
        return unpack('b', self.s.read(1))[0]

    def readU8(self):
        return unpack('B', self.s.read(1))[0]

    def readS16(self):
        self.align(2)
        return unpack('>h', self.s.read(2))[0]

    def readU16(self):
        self.align(2)
        return unpack('>H', self.s.read(2))[0]

    def readS32(self):
        self.align(4)
        return unpack('>i', self.s.read(4))[0]

    def readU32(self):
        self.align(4)
        return unpack('>I', self.s.read(4))[0]

    def readS64(self):
        self.align(8)
        (x, y) = unpack(">iI", self.s.read(8))
        return (x<<32) | y

    def readU64(self):
        self.align(8)
        (x, y) = unpack(">2I", self.s.read(8))
        return (x<<32) | y
 
    def struct(self, val):
        val.unserialize(self)
        return val

    def read_byte_string(self, length):
        return self.s.read(length)

    def read_string(self, length, max_len):
        string = self.s.read(length).decode()
        if max_len > 1:
            rem = max_len - length
            if rem < 0:
                raise ValueError("String too long: %d (%d)", (length, max_len))
            self.s.read(rem)
        return string

    def int_array(self, length, max_len, read_method):
        lst = [ read_method() for i in range(length) ]
        if max_len > 1:
            rem = max_len - length
            if rem < 0:
                raise ValueError("Array too long: %d (%d)", (length, max_len))
            for i in range(rem):
                read_method()
        return ogre.signal.Array(lst)

    def composite_array(self, class_, length, max_len, read_method):
        lst = [ read_method(class_()) for i in range(length) ]
        if max_len > 1:
            rem = max_len - length
            if rem < 0:
                raise ValueError("Array too long: %d (%d)", (length, max_len))
            for i in range(rem):
                read_method(class_())
        return ogre.signal.Array(lst)


# ----------------------------------------------------------------
class ByteBufferWriter(object):
    #__slots__ = ['s']

    def __init__(self, stream):
        self.s = stream

    def pad(self, padbytes):
        if padbytes != 0:
            self.s.write(pack('%dx' % (padbytes)))

    def align(self, wordlen):
        alignment = self.s.tell() % wordlen
        if alignment != 0:
            padbytes = wordlen - alignment
            self.s.write(pack('%dx' % (padbytes)))

    def align2(self):
        padbytes = 2 - self.s.tell() % 2
        if padbytes < 2:
            self.s.write(pack('%dx' % (padbytes)))
        
    def align4(self):
        padbytes = 4 - self.s.tell() % 4
        if padbytes < 4:
            self.s.write(pack('%dx' % (padbytes)))

    def align8(self):
        padbytes = 8 - self.s.tell() % 8
        if padbytes < 8:
            self.s.write(pack('%dx' % (padbytes)))

    def seek(self, pos):
        self.s.seek(pos)

    # --- writers
    
    def writeS8(self, val):
        if val < -0x80 or val > 0x7f:
            raise ValueError()
        self.s.write(pack('b', val))

    def writeU8(self, val):
        if val < 0 or val > 0xff:
            raise ValueError()
        self.s.write(pack('B', val))

    def writeS16(self, val):
        if val < -0x8000 or val > 0x7fff:
            raise ValueError()
        self.align2()
        self.s.write(pack('>h', val))

    def writeU16(self, val):
        if val < 0 or val > 0xffff:
            raise ValueError()
        self.align2()
        self.s.write(pack('>H', val))

    def writeS32(self, val):
        if val < -0x80000000 or val > 0x7fffffff:
            raise ValueError()
        self.align4()
        self.s.write(pack('>i', val))

    def writeU32(self, val):
        if val < 0 or val > 0xffffffff:
            raise ValueError()
        self.align4()
        self.s.write(pack('>I', val))

    def writeS64(self, val):
        if val < -0x8000000000000000 or val > 0x7fffffffffffffff:
            raise ValueError()
        self.align8()
        x = (val>>32) & 0xffffffff
        y = val & 0xffffffff
        self.s.write(pack('>iI', x, y))

    def writeU64(self, val):
        if val < 0 or val > 0xffffffffffffffff:
            raise ValueError()
        self.align8()
        x = (val>>32) & 0xffffffff
        y = val & 0xffffffff
        self.s.write(pack('>2I', x, y))

    def struct(self, val):
        val.serialize(self)

    def write_byte_string(self, val):
        self.s.write(val)

    def write_string(self, string, max_len):
        lst = string.encode()
        self.s.write(lst)
        if max_len > 1:
            rem = max_len - len(lst)
            if rem < 0:
                raise ValueError("Array too long: %d (max %d)" % (len(lst), max_len))
            #self.s.write(b"\0" * rem)
            self.s.write(pack('%dx' % (rem)))

    def int_array(self, lst, max_len, write_method):
        [ write_method(val) for val in lst ]
        if max_len > 1:
            rem = max_len - len(lst)
            if rem < 0:
                raise ValueError("Array too long: %d (max %d)" % (len(lst), max_len))
            for i in range(rem):
                write_method(0)

    def composite_array(self, class_, lst, max_len, write_method):
        [ write_method(val) for val in lst ]
        if max_len > 1:
            rem = max_len - len(lst)
            if rem < 0:
                raise ValueError("Array too long: %d (max %d)" % (len(lst), max_len))
            for i in range(rem):
                #write_method(class_())
                class_().serialize(self)

# End of file
