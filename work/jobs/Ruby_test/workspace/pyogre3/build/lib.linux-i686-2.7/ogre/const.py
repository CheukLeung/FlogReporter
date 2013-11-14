# ----------------------------------------------------------------
# const.py
# ----------------------------------------------------------------
"""
Common constants and exceptions for Ogre.
"""

# Predefined signal numbers
HUNT_SIG              = 251
ATTACH_SIG            = 252

# Ogre exceptions
class ConnectionLostError(Exception):
    """Connection with the target lost."""
    pass

class NotSupportedError(Exception):
    """Not supported by server."""
    pass

class ServerError(Exception):
    """Error returned from server."""
    pass

# End of file
