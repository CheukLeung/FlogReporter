# ----------------------------------------------------------------
# signals.py - Signal definitions
# ----------------------------------------------------------------

import ogre


# ----------------------------------------------------------------
class SyncReq(ogre.Signal):
    SIGNO = 12000+1

    ATTR_LIST = [ 't1', 't2', 't3', 't4', 'data' ]

    def __init__(self):
        ogre.Signal.__init__(self, self.SIGNO)
        self.t1 = 0
        self.t2 = 0
        self.t3 = 0
        self.t4 = 0
        self.data = b""

    def serialize(self, writer):
        writer.writeU32(self.t1)
        writer.writeU32(self.t2)
        writer.writeU32(self.t3)
        writer.writeU32(self.t4)
        writer.writeU32(len(self.data))
        writer.write_byte_string(self.data)

    def unserialize(self, reader):
        self.t1 = reader.readU32()
        self.t2 = reader.readU32()
        self.t3 = reader.readU32()
        self.t4 = reader.readU32()
        len = reader.readU32()
        self.data = reader.read_byte_string(len)


# ----------------------------------------------------------------
class HuntInd(ogre.Signal):
    SIGNO = 9990

    ATTR_LIST = []
    
    def __init__(self):
        ogre.Signal.__init__(self, self.SIGNO)

    def serialize(self, writer):
        writer.writeU32(0)


# ----------------------------------------------------------------
class UnregisteredInd(ogre.Signal):
    SIGNO = 9991

    ATTR_LIST = []

    def __init__(self):
        ogre.Signal.__init__(self, self.SIGNO)


# ----------------------------------------------------------------
ogre.Signal.register(HuntInd.SIGNO, HuntInd)
ogre.Signal.register(SyncReq.SIGNO, SyncReq)

# End of file
