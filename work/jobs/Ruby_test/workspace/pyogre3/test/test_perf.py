# ----------------------------------------------------------------
# test_perf.py - 
# ----------------------------------------------------------------
import ogre
import ogre_sig

import unittest
import logging
import logging.config
import time
import os


# ----------------------------------------------------------------
class TestPerformance(unittest.TestCase):

   def setUp(self):
      self.url = '%s://%s:%s' % (os.environ['OGRE_COMM'],
                                 os.environ['OGRE_NODE'],
                                 os.environ['OGRE_PORT'])

   def test_small_signals(self):
      p = ogre.Process(self.url, "ogre_echo")
      t1 = time.time()
      for i in range (100):
         self._send_receive_small_signal(p)
      t2 = time.time()
      print 'small signal, 100 send and receive:', (t2 - t1), 'sec'

   def test_big_signals(self):
      p = ogre.Process(self.url, "ogre_proc")
      t1 = time.time()
      for i in range (100):
         self._send_receive_big_signal(100, 100, p)
      t2 = time.time()
      print 'big signal, 100 send and receive:', (t2 - t1), 'sec'

   def _send_receive_big_signal(self, req_size, rsp_size, p):
      sig = ogre_sig.ogre_big_req()
      sig.requested_data_size = rsp_size
      sig.data_size = req_size
      sig.data[:] = [0x55 for i in range(req_size)]

      # Send and wait for a reply
      p.send(sig)
      reply = p.receive()

      # Verify the reply
      self.assertEqual(1, reply.ok)
      self.assertEqual(rsp_size, len(reply.data))
      map(lambda e: self.assertEqual(e, 0xaa), reply.data)

   def _send_receive_small_signal(self, p):
      sig = ogre_sig.ogre_sync_req()
      sig.t1 = 101
      sig.t2 = 102
      sig.t3 = 103
      sig.t4 = 104

      # Send and wait for a reply
      p.send(sig)
      reply = p.receive()

      # Verify the reply
      self.assertEqual(101, reply.t1)
      self.assertEqual(102, reply.t2)
      self.assertEqual(103, reply.t3)
      self.assertEqual(104, reply.t4)

   def tearDown(self):
      pass


# ----------------------------------------------------------------      
if __name__ == '__main__':
   logging.config.fileConfig('testlog.ini')
   unittest.main()

# End of file
