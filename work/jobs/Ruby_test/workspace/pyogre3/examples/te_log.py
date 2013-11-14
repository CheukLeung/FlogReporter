# ----------------------------------------------------------------
# te_log.py
# ----------------------------------------------------------------
import ogre

OM_SIGBASE        = 3160000
OMCSF_SIGBASE     = (OM_SIGBASE + 1400)
OMCSF_LOG_SIGBASE = (OMCSF_SIGBASE + 50)
OMCSF_LOG_MONITOR_IND = (OMCSF_LOG_SIGBASE + 6)    


# ---
class Cs_traceTStamp(ogre.Struct):

    def __init__(self):
        ogre.Struct.__init__(self)
        self.ticks_ul = 0
        self.usecs_ul = 0

    def serialize(self, writer):
        writer.writeU32(self.ticks_ul)
        writer.writeU32(self.usecs_ul)

    def unserialize(self, reader):
        self.ticks_ul = reader.readU32()
        self.usecs_ul = reader.readU32()

# ---
class OMCSF_logDataS(ogre.Struct):

    def __init__(self):
        ogre.Struct.__init__(self)
        self.absTimeSec = 0
        self.absTimeTick = 0
        self.lineNo = 0
        self.fileNamePos = 0
        self.procNamePos = 0
        self.msgPos = 0
        self.binDataPos = 0
        self.binDataLen = 0
        self.group = 0
        self.data = ""

    def serialize(self, writer):
        writer.writeU32(self.absTimeSec)
        writer.writeU32(self.absTimeTick)
        writer.writeU16(self.lineNo)
        writer.writeU16(self.fileNamePos)
        writer.writeU16(self.procNamePos)
        writer.writeU16(self.msgPos)
        writer.writeU16(self.binDataPos)
        writer.writeU16(self.binDataLen)
        writer.writeU32(self.group)
        writer.array(self.data, writer.writeU8)

    def unserialize(self, reader):
        self.absTimeSec = reader.readU32()
        self.absTimeTick = reader.readU32()
        self.lineNo = reader.readU16()
        self.fileNamePos = reader.readU16()
        self.procNamePos = reader.readU16()
        self.msgPos = reader.readU16()
        self.binDataPos = reader.readU16()
        self.binDataLen = reader.readU16()
        self.group = reader.readU32()
        self.data = reader.string(reader.len())

# ---
class OMCSF_logMonitorConnectReqS(ogre.Signal):
    SIGNO = OMCSF_LOG_SIGBASE + 3

    def __init__(self):
        ogre.Signal.__init__(self, self.SIGNO)


# ---
class OMCSF_logMonitorConnectCfmS(ogre.Signal):
    SIGNO = OMCSF_LOG_SIGBASE + 4

    def __init__(self):
        ogre.Signal.__init__(self, self.SIGNO)
        self.result = 0
        self.tickLength = 0

    def serialize(self, writer):
        writer.writeU32(self.result)
        writer.writeU32(self.tickLength)

    def unserialize(self, reader):
        self.result = reader.readU32()
        self.tickLength = reader.readU32()


# ---
class OMCSF_logMonitorIndS (ogre.Signal):
    SIGNO = OMCSF_LOG_SIGBASE + 6

    def __init__(self):
        ogre.Signal.__init__(self, self.SIGNO)
        self.acknowledge = 0
        self.logged = 0
        self.relTimeStamp = Cs_traceTStamp()
        self.logData = OMCSF_logDataS()

    def serialize(self, writer):
        writer.writeU32(self.acknowledge)
        writer.writeU32(self.logged)
        writer.struct(self.relTimeStamp)
        writer.struct(self.logData)

    def unserialize(self, reader):
        self.acknowledge = reader.readU32()
        self.logged = reader.readU32()
        self.relTimeStamp = reader.struct(self.relTimeStamp)
        self.logData = reader.struct(self.logData)


# ---
class OMCSF_logMonitorAckIndS(ogre.Signal):
    SIGNO = OMCSF_LOG_SIGBASE + 7

    def __init__(self):
        ogre.Signal.__init__(self, self.SIGNO)
    

# ---
class OMCSF_logReadIndS (ogre.Signal):
    SIGNO = OMCSF_LOG_SIGBASE + 12

    def __init__(self):
        ogre.Signal.__init__(self, self.SIGNO)
        self.acknowledge = 0
        self.tickLength = 0
        self.relTimeStamp = Cs_traceTStamp()
        self.logData = OMCSF_logDataS()

    def serialize(self, writer):
        writer.writeU32(self.acknowledge)
        writer.writeU32(self.tickLen)
        writer.struct(self.relTimeStamp)
        writer.struct(self.logData)

    def unserialize(self, reader):
        self.acknowledge = reader.readU32()
        self.tickLen = reader.readU32()
        self.relTimeStamp = reader.struct(self.relTimeStamp)
        self.logData = reader.struct(self.logData)

# ---
class OMCSF_logReadAckIndS(ogre.Signal):
    SIGNO = OMCSF_LOG_SIGBASE + 13

    def __init__(self):
        ogre.Signal.__init__(self, self.SIGNO)
    
# ---
ogre.Signal.register(OMCSF_logMonitorConnectReqS.SIGNO, OMCSF_logMonitorConnectReqS)
ogre.Signal.register(OMCSF_logMonitorConnectCfmS.SIGNO, OMCSF_logMonitorConnectCfmS)
ogre.Signal.register(OMCSF_logMonitorIndS.SIGNO,    OMCSF_logMonitorIndS)
ogre.Signal.register(OMCSF_logMonitorAckIndS.SIGNO, OMCSF_logMonitorAckIndS)
ogre.Signal.register(OMCSF_logReadIndS.SIGNO,       OMCSF_logReadIndS)
ogre.Signal.register(OMCSF_logReadAckIndS.SIGNO,    OMCSF_logReadAckIndS)

# End of file
