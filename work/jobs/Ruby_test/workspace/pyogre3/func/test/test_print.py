# = Test Case
# - [VS OGRE.PROC.ERR.REP.RUBY] PROCESS_ERROR_REPORTING
#
# = Description
# Verifies that the class <tt>OGRE::Process</tt> raises exceptions if
# errors occur during execution.
#
# = Requirement
# - [RS OGRE.ERR.REP] ERROR_REPORTING
#
# = Action / Event
# ==== Action:
# Begin provoke errors; bad url, hunt without name and pid,
# <tt>OGRE::Process.new</tt> with missing arguments,
# Supervision of hardcoded pid, Hunt non-existent process,
# use bad timeout value
# ==== Expected result:
# PASSED if the provoked errors raised expected exceptions
#
# = Communication and hosts:
# - Execute the test on Linux and Solaris.
#
# = Comment
#


# ----------------------------------------------------------------
# test_print.py - Test case that redirects data written to stdout 
#                 on the target to the host
# ----------------------------------------------------------------
import ogre
import ogre_func

import unittest
import os

# ----------------------------------------------------------------
class TestPrint(unittest.TestCase):
   
   # Set to 1 to get a printout of the redirected data
   # Set to 0 to not get a printout of the redirected data
   PrintData = 1
   
   # Setup connection
   def setUp(self):
      # String used to connect to target
      self.url = '%s://%s:%s' % (os.environ['OGRE_COMM'], os.environ['OGRE_NODE'], os.environ['OGRE_PORT'])
      # Setup connection to target
      self.conn = ogre.create(self.url, "testogre")
      # Hunt for the OGRE process running on the target
      self.conn.hunt("ogre_proc_exec")
      # Save the PID of that process
      self.pid = self.conn.receive().sender()

   # Test catching of data written to stdout on target
   def test_print(self):
      # Create a new signal object
      sig1 = ogre_func.OgrePrint_test_functionExecute()
      
      # Change this value to enable/disable forwarding of stdout to host
      # 1 - Forward stdout to host
      # 0 - Do not forward stdout to host
      sig1.catch_stdout = 1
      
      # Send signal
      self.conn.send(sig1, self.pid)
      
      # Receive signal (stdout-output)
      sig2 = self.conn.receive()
      
      # The stdout-output is returned in one signal (OGRE_STDOUT_DATA)
      # Convert received array of chars to string
      ReceivedString = ''.join([chr(char) for char in sig2.data])
      
      # Ensure that some data is received
      self.assertTrue(ReceivedString != "")
      
      # Print received data if 'PrintData' equals 1
      if self.PrintData == 1:
         print ("\n<---- Printout from function execution: ---->\n" + ReceivedString + "<---- End of printout ---->")
      
      # Receive signal (the functions return value)
      sig2 = self.conn.receive()
      
   # Close connection to target
   def tearDown(self):
      self.conn.close()
      pass

# ----------------------------------------------------------------      
if __name__ == '__main__':
   unittest.main()

# End of file
