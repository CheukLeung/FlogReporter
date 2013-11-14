# ----------------------------------------------------------------
# array_sig.py
# ----------------------------------------------------------------
import ogre


class StructB(ogre.Struct):

    ATTR_LIST = [ 'foo', 'bar' ]

    def __init__(self):
        self.foo = 0
        self.bar = 0

    def serialize(self, abi):
        abi.align(2)
        abi.writeU8(self.foo)
        abi.writeU16(self.bar)

    def unserialize(self, abi):
        abi.align(2)
        self.foo = abi.readU8()
        self.bar = abi.readU16()

class ArraySig(ogre.Signal):
    SIGNO = 10

    ATTR_LIST = [ 'a', 'b', 'c', 'fix1_array', 'fix2_array', 'dyn1_array', 'dyn2_array']

    def __init__(self):
        ogre.Signal.__init__(self, self.SIGNO)
        self.a = 0
        self.b = StructB()
        self.c = StructB()
        self.fix1_array = ogre.Array([ StructB() for i in range(3) ])
        self.fix2_array = ogre.Array([ 0 for i in range(4) ])
        self.dyn1_array_len = 0
        self.dyn1_array = ogre.Array( [StructB()] )
        self.dyn2_array_len = 0
        self.dyn2_array = ogre.Array( [0] )

    def serialize(self, abi):
        abi.writeU32(self.a)
        abi.struct(self.b)
        abi.struct(self.c)
        abi.composite_array(StructB, self.fix1_array, 3, abi.struct)  # Fix array of struct
        abi.int_array(self.fix2_array, 4, abi.writeU16)  # Fix array of uint16
        abi.writeU16(len(self.dyn1_array))
        abi.composite_array(StructB, self.dyn1_array, 1, abi.struct)  # Dynamic array of struct
        abi.writeU16(len(self.dyn2_array))
        abi.int_array(self.dyn2_array, 1, abi.writeU8)   # Dynamic array of uint8

    def unserialize(self, abi):
        self.a = abi.readU32()
        self.b = abi.struct(self.b)
        self.c = abi.struct(StructB())
        self.fix1_array = abi.composite_array(StructB, 3, 3, abi.struct)  # Fix array of struct
        self.fix2_array = abi.int_array(4, 4, abi.readU16)           # Fix array of uint16
        self.dyn1_array_len = abi.readU16()
        self.dyn1_array = abi.composite_array(StructB, self.dyn1_array_len, 1, abi.struct)
        self.dyn2_array_len = abi.readU16()
        self.dyn2_array = abi.int_array(self.dyn2_array_len, 1, abi.readU8)


# ----------------------------------------------------------------
ogre.Signal.register(ArraySig.SIGNO, ArraySig)


# End of file
