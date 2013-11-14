
# ----
class (ogre.Struct):
    """Signal description for struct """

    ATTR_LIST = [
    ]
    
    def __init__(self):
        ogre.Struct.__init__(self)

    def serialize(self, writer, tag=None):
        writer.align(4)
        writer.align(4)

    def unserialize(self, reader, tag=None):
        reader.align(4)
        reader.align(4)
