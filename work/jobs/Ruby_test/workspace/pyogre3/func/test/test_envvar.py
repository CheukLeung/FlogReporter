# ----------------------------------------------------------------
# test_envvar.py - Test cases that tests setting and reading 
#                  environment variables
# ----------------------------------------------------------------
import ogre
import ogre_func

import unittest
import os

# ----------------------------------------------------------------
class TestEnvvar(unittest.TestCase):

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
   
   # Test case: Environment variables
   # This test case does the following:
   # 1. Define a new environment variable
   # 2. Read the value of the environment variable
   # 3. Change the value of the environment variable
   # 4. Read the value of the environment variable again
   def test_envvar(self):
      # 1. Define a new environment variable
      # ----------------------------------------------------------
      # 1.a Copy a string with the variable name to the target memory
      # Create a new signal object
      sig_out = ogre_func.OgreStringWriteRequest()
      # The name of the new enviroment variable
      string = 'TestVar'
      # Convert the string into a char array
      sig_out.str = list(ord(char) for char in string)
      # Send the signal
      self.conn.send(sig_out, self.pid)
      # Receive the reply. It contains a pointer to the string 
      # that is now stored in the memory on the target
      sig_in = self.conn.receive()
      NamePointer = sig_in.pointer
      
      # 1.b Copy a string with the variable value to the target memory
      # Create a new signal object
      sig_out = ogre_func.OgreStringWriteRequest()
      # The Value
      ValueString = 'TestValue'
      # Convert the string into a char array
      sig_out.str = list(ord(char) for char in ValueString)
      # Send the signal
      self.conn.send(sig_out, self.pid)
      # Receive the reply. It contains a pointer to the string 
      # that is now stored in the memory on the target
      sig_in = self.conn.receive()
      ValuePointer = sig_in.pointer
      
      # 1.c Define a new environment variable
      # Create a new signal object
      sig_out = ogre_func.OgreSet_envExecute()
      # The PID of the process that shall have the environment variable
      sig_out.param0 = self.pid
      # A pointer to the variable name
      sig_out.param1 = NamePointer
      # A pointer to the variable value
      sig_out.param2 = ValuePointer
      # Send the signal
      self.conn.send(sig_out, self.pid)
      # Receive reply
      sig_in = self.conn.receive()
      # Validate the return value
      self.assertTrue(sig_in.return_value == 0)
      
      # 2. Read the value of the environment variable
      # ----------------------------------------------------------
      # 2.a Get a pointer to the enviromnent variable value
      # Create a new signal object
      sig_out = ogre_func.OgreGet_envExecute()
      # The PID of the process that has the environment variable
      sig_out.param0 = self.pid
      # A pointer to the variable name
      sig_out.param1 = NamePointer
      # Send the signal
      self.conn.send(sig_out, self.pid)
      # Receive reply
      sig_in = self.conn.receive()
      # Save pointer to the read value
      ReadValuePointer = sig_in.return_value
      
      # 2.b Read the value from the pointer
      # Create a new signal object
      sig_out = ogre_func.OgreStringReadRequest()
      # A pointer to the value to be read
      sig_out.pointer = ReadValuePointer
      # Send the signal
      self.conn.send(sig_out, self.pid)
      # Receive reply. It contains a char array
      sig_in = self.conn.receive()
      # Convert char array to string
      ReceivedValue = ''.join([chr(char) for char in sig_in.str])
      #print(ReceivedValue)
      # Verify the reply (Allow a trailing NULL char in the read value)
      self.assertTrue(ReceivedValue == ValueString + chr(0) or ReceivedValue == ValueString)
      
      # 3. Change the value of the environment variable
      # ----------------------------------------------------------
      # 3.a Copy a string with the new variable value to the target memory
      # Create a new signal object
      sig_out = ogre_func.OgreStringWriteRequest()
      # The Value
      ModValueString = 'ModifiedValue'
      # Convert the string into a char array
      sig_out.str = list(ord(char) for char in ModValueString)
      # Send the signal
      self.conn.send(sig_out, self.pid)
      # Receive the reply. It contains a pointer to the string 
      # that is now stored in the memory on the target
      sig_in = self.conn.receive()
      ModValuePointer = sig_in.pointer
      
      # 3.b Change the environment variable value
      # Create a new signal object
      sig_out = ogre_func.OgreSet_envExecute()
      # The PID of the process that has have the environment variable
      sig_out.param0 = self.pid
      # A pointer to the variable name
      sig_out.param1 = NamePointer
      # A pointer to the variable value
      sig_out.param2 = ModValuePointer
      # Send the signal
      self.conn.send(sig_out, self.pid)
      # Receive reply
      sig_in = self.conn.receive()
      # Validate the return value
      self.assertTrue(sig_in.return_value == 0)
      
      # 4. Read the value of the environment variable again
      # ----------------------------------------------------------
      # 4.a Get a pointer to the enviromnent variable value
      # Create a new signal object
      sig_out = ogre_func.OgreGet_envExecute()
      # The PID of the process that has the environment variable
      sig_out.param0 = self.pid
      # A pointer to the variable name
      sig_out.param1 = NamePointer
      # Send the signal
      self.conn.send(sig_out, self.pid)
      # Receive reply
      sig_in = self.conn.receive()
      # Save pointer to the read value
      ReadModValuePointer = sig_in.return_value
      
      # 4.b Read the value from the pointer
      # Create a new signal object
      sig_out = ogre_func.OgreStringReadRequest()
      # A pointer to the value to be read
      sig_out.pointer = ReadModValuePointer
      # Send the signal
      self.conn.send(sig_out, self.pid)
      # Receive reply. It contains a char array
      sig_in = self.conn.receive()
      # Convert char array to string
      ReceivedValue = ''.join([chr(char) for char in sig_in.str])
      #print(ReceivedValue)
      # Verify the reply (Allow a trailing NULL char in the read value)
      self.assertTrue(ReceivedValue == ModValueString + chr(0) or ReceivedValue == ModValueString)
      
   # Close connection to target
   def tearDown(self):
      self.conn.close()

# ----------------------------------------------------------------      
if __name__ == '__main__':
   unittest.main()

# End of file
