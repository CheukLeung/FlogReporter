
# ----
class number(ogre.Struct):
    """Signal description for array number"""

    ATTR_LIST = [
    ]
    
    def __init__(self):
        ogre.Struct.__init__(self)

    def serialize(self, writer, tag=None):
        writer.align(8)
        writer.align(8)

    def unserialize(self, reader, tag=None):
        reader.align(8)
        reader.align(8)
