# ----------------------------------------------------------------
# test_process.py - Unit test program for Process
# ----------------------------------------------------------------
from __future__ import with_statement
import functools

import unittest
import logging
import logging.config
import select
import time
import os

import ogre
import ogre_sig



# ----------------------------------------------------------------
class TestProcess(unittest.TestCase):

   def setUp(self):
      self.url = '%s://%s:%s' % (os.environ['OGRE_COMM'],
                                 os.environ['OGRE_NODE'],
                                 os.environ['OGRE_PORT'])


   def test_echo(self):
      proc = ogre.Process(self.url, 'ogre_echo', supervise=True)
      sig = ogre_sig.OGRE_SYNC_REQ()
      sig.t1 = 47
      proc.send(sig)
      rsp = proc.receive([ogre_sig.OGRE_SYNC_REQ.SIGNO])
      self.assertEqual(47, rsp.t1)
      proc.close()

   def test_multiple(self):
      proc1 = ogre.Process(self.url, 'ogre_echo', supervise=True)
      proc2 = ogre.Process(self.url, 'ogre_proc', supervise=True)

      sig = ogre_sig.OGRE_SYNC_REQ()
      sig.t1 = 37
      proc1.send(sig)
      proc2.send(sig)
      proc2.send(sig)

      count = 0
      for proc, sig in ogre.Process.receive_any([proc1, proc2], timeout=1):
         self.assertEqual(37, sig.t1)
         count += 1
         #print 'sender: %x, t1: %d, t2: %d' % (sig.sender(), sig.t1, sig.t2)

      self.assertEqual(3, count)
      proc1.close()
      proc2.close()


   def test_with_statement(self):
      with ogre.Process(self.url, 'ogre_echo') as proc:
         sig1 = ogre_sig.OGRE_SYNC_REQ()
         proc.send(sig1)
         sig2 = proc.receive()

      self.assertRaises(ogre.ConnectionLostError, proc.receive)
         

##    def test_iter_statement(self):
##       sig1 = ogre_sig.OGRE_SYNC_REQ()
##       count = 0
      
##       with ogre.Process(self.url, 'ogre_echo') as proc:
##          proc.send(sig1)
##          proc.send(sig1)

##          for sig in proc:
##             self.assertEqual(sig1, sig)
##             count += 1
##             if count == 2:
##                break

##          sig2 = proc.receive(timeout=0.2)
##          self.assertEqual(None, sig2)
         

   def test_iter_statement_2(self):
      sig1 = ogre_sig.OGRE_SYNC_REQ()
      count = 0
      
      with ogre.Process(self.url, 'ogre_echo') as proc:
         receive_w_tmo = functools.partial(proc.receive, timeout=1.0)
         proc.send(sig1)
         proc.send(sig1)

         for sig in iter(receive_w_tmo, None):
            self.assertEqual(sig1, sig)
            count += 1

         self.assertEqual(2, count)
         

   def tearDown(self):
      pass


# ----------------------------------------------------------------      
if __name__ == '__main__':
   logging.config.fileConfig('testlog.ini')
   unittest.main()

# End of file
