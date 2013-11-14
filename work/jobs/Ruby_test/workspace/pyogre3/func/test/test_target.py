# ----------------------------------------------------------------
# test_target.py - Test cases that get system uptime and performs
#                  some semaphores operations
# ----------------------------------------------------------------
import ogre
import ogre_func

import unittest
import os

# ----------------------------------------------------------------
class TestTarget(unittest.TestCase):

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
   
   # Get number of ticks since system start, get_ticks()
   def test_get_ticks(self):
      # Create a new signal object
      sig1 = ogre_func.OgreGet_ticksExecute()
      # Send the signal
      self.conn.send(sig1, self.pid)
      # Receive the reply
      sig2 = self.conn.receive()
      # Verify that the received value is larger than 0
      self.assertTrue(sig2.return_value > 0)
   
   # Get number of ticks since system start, get_systime()
   def test_get_systime(self):
      # Create a new signal object
      sig1 = ogre_func.OgreGet_systimeExecute()
      # Send the signal
      self.conn.send(sig1, self.pid)
      # Receive the reply
      sig2 = self.conn.receive()
      # Verify that the received value is larger than 0
      self.assertTrue(sig2.return_value > 0)

   def test_semaphore(self):
      # ---------- Create semaphore
      # Create a new signal object
      sig1 = ogre_func.OgreCreate_semExecute()
      # Semaphore initiation value = 1
      sig1.param0 = 1
      # Send signal
      self.conn.send(sig1, self.pid)
      sig2 = self.conn.receive()
      # Verify reply
      self.assertTrue(type(sig2) == type(ogre_func.OgreCreate_semReply()))
      # Pointer to the semaphore
      self.SemPointer = sig2.return_value
   
      # ----------  Signal semaphore two times
      # Create a new signal object
      sig1 = ogre_func.OgreSignal_semExecute()
      # Pointer to the semaphore
      sig1.param0 = self.SemPointer
      # Send signal twice
      self.conn.send(sig1, self.pid)
      self.conn.send(sig1, self.pid)
      
      # Receive and verify reply type twice
      sig2 = self.conn.receive()
      self.assertTrue(type(sig2) == type(ogre_func.OgreSignal_semReply()))
      sig2 = self.conn.receive()
      self.assertTrue(type(sig2) == type(ogre_func.OgreSignal_semReply()))
      
      # ---------- Get semaphore value
      # Create a new signal object
      sig1 = ogre_func.OgreGet_semExecute()
      # Pointer to the semaphore
      sig1.param0 = self.SemPointer
      # Send signal
      self.conn.send(sig1, self.pid)
      # Receive reply
      sig2 = self.conn.receive()
      # Verify reply type
      self.assertTrue(type(sig2) == type(ogre_func.OgreGet_semReply()))
      # Verify semaphore value (3)
      self.assertTrue(sig2.return_value == 3)
      
      # ---------- Wait for semaphore
      # Create a new signal object
      sig1 = ogre_func.OgreWait_semExecute()
      # Pointer to the semaphore
      sig1.param0 = self.SemPointer
      # Send signal
      self.conn.send(sig1, self.pid)
      # Receive reply
      sig2 = self.conn.receive()
      # Verify reply type
      self.assertTrue(type(sig2) == type(ogre_func.OgreWait_semReply()))
      
      # ---------- Get semaphore value
      # Create a new signal object
      sig1 = ogre_func.OgreGet_semExecute()
      # Pointer to the semaphore
      sig1.param0 = self.SemPointer
      # Send signal
      self.conn.send(sig1, self.pid)
      # Receive reply
      sig2 = self.conn.receive()
      # Verify reply type
      self.assertTrue(type(sig2) == type(ogre_func.OgreGet_semReply()))
      # Verify semaphore value (2)
      self.assertTrue(sig2.return_value == 2)      
      
      # ---------- Kill semaphore
      # Create a new signal object
      sig1 = ogre_func.OgreKill_semExecute()
      # Pointer to the semaphore
      sig1.param0 = self.SemPointer
      # Send signal
      self.conn.send(sig1, self.pid)
      # Receive signal
      sig2 = self.conn.receive()
      # Verify reply type
      self.assertTrue(type(sig2) == type(ogre_func.OgreKill_semReply()))
   
   # Close connection to target
   def tearDown(self):
      self.conn.close()
      pass

# ----------------------------------------------------------------      
if __name__ == '__main__':
   unittest.main()

# End of file
