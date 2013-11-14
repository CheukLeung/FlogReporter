# ----------------------------------------------------------------
# __init__.py
# ----------------------------------------------------------------
"""
This package contains modules for communication with OSE processes on
Cello nodes using OSE Gateway or Linx. 

Functions:
  ogre.create(url, name) - Create a connection
  
Main classes:
  ogre.Osegw   - OSE Gateway connection
  ogre.Linx    - LINX connection
  ogre.Process - Target process
  ogre.Signal  - OSE signal

Exceptions:
  ogre.ConnectionLostError - Connection lost with the target node
  ogre.NotSupportedError   - Not supported by the server
  ogre.ServerError         - Error returned from server
"""

__version__ = '1.0'

from ogre.const import *
from ogre.osegw import *
from ogre.linx import *
from ogre.factory import *
from ogre.signal import *
from ogre.process import *
from ogre.dsp_process import *
from ogre.stub import *
from ogre.constraints import *

# End of file
