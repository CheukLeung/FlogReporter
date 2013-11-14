# ----------------------------------------------------------------
# test_supervision.py - Test of link supervision
# ----------------------------------------------------------------
import ogre
import ogre_sig

import unittest
import logging
import logging.config
import time
import os


# ----------------------------------------------------------------
class EchoStub(ogre.Stub):
   """
   """
   def run(self):
      while 1:
         sig = self.conn.receive()
         if isinstance(sig, ogre.UnknownSignal):
            return
         self.conn.send(sig, sig.sender())

         
# ----------------------------------------------------------------
class TestSupervision(unittest.TestCase):

   def setUp(self):
      self.url = '%s://%s:%s' % (os.environ['OGRE_COMM'],
                                 os.environ['OGRE_NODE'],
                                 os.environ['OGRE_PORT'])


   def test_link_down_process(self):
      # Create a echo stub process
      self.stub = EchoStub(self.url, "my_echo_proc")

      # Hunt the stub  process
      proc = ogre.Process(self.url, 'my_echo_proc', supervise=False)

      # Test if working
      sig = ogre_sig.ogre_sync_req()
      sig.t1 = 47
      proc.send(sig)
      rsp = proc.receive()
      self.assertEqual(47, rsp.t1)

      # Kill the node
      proc.send(ogre.UnknownSignal(1))
      print 'Stop the node:'
      print '  telnet %s' % (os.environ['OGRE_NODE'])
      print '  reload'

      # All process methods shall raise exception
      self.assertRaises(ogre.ConnectionLostError, proc.receive)
      self.assertRaises(ogre.ConnectionLostError, proc.send, sig)
      proc.close()


   def test_link_down(self):
      # Create a echo stub process
      self.stub = EchoStub(self.url, "my_echo_proc")

      # Hunt the stub  process
      gw = ogre.create(self.url, "testprocess")
      gw.hunt("my_echo_proc")
      pid = gw.receive().sender()

      # Test if working
      sig = ogre_sig.ogre_sync_req()
      sig.t1 = 47
      gw.send(sig, pid)
      rsp = gw.receive()
      self.assertEqual(47, rsp.t1)

      # Kill the node
      gw.send(ogre.UnknownSignal(1), pid)
      print 'Stop the node:'
      print '  telnet %s' % (os.environ['OGRE_NODE'])
      print '  reload'

      # All connection methods shall raise exception now
      self.assertRaises(ogre.ConnectionLostError, gw.receive)
      self.assertRaises(ogre.ConnectionLostError, gw.send, sig, pid)
      self.assertRaises(ogre.ConnectionLostError, gw.hunt, 'kalle')
      gw.close()


   def tearDown(self):
      pass


# ----------------------------------------------------------------      
if __name__ == '__main__':
   logging.config.fileConfig('testlog.ini')
   unittest.main()

# End of file
