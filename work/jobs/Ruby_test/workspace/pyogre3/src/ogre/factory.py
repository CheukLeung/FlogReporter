# ----------------------------------------------------------------
# factory.py
# ----------------------------------------------------------------
"""
Top level functions for Ogre.
"""
import logging

import ogre.osegw
import ogre.linx


# ----------------------------------------------------------------
class _NullHandler(logging.Handler):
    """Dummylogger  handler"""
    def emit(self, record):
        pass

# Add a dummy handler to keep the logger quiet in case the
# user application doesn't configure the logger
logging.getLogger('ogre').addHandler(_NullHandler())


# ----------------------------------------------------------------
def create(url, name):
    """
    Creates an OGRE connection. Two communication methods are
    supported; OSE Gateway and Linx. The first part of the URL
    specifies the communication method.

    For OSE Gateway connections the specified name is the name of the
    proxy process on the target.  For Linx connections the specified
    name is the name of endpoint on the host.

    Parameters:
        url       -- connection method and address
        name      -- the name of the proxy process

    Usage:
        >>> import ogre
        >>> gw1 = ogre.create('linx', 'tp_name')
        >>> gw2 = ogre.create('tcp://172.17.226.201:22001', 'tp_name')

    """
    if url[:4] == 'linx':
        return ogre.linx.Linx(name)
    elif url[:3] == 'tcp':
        return ogre.osegw.Osegw(url, name)

    # Unknown protocol
    raise Exception(
        "malformed URL: '%s' supported protocols: 'linx' or 'tcp'" % url)

# ----------------------------------------------------------------
if __name__ == "__main__":
    import doctest
    doctest.testmod()

# End of file
