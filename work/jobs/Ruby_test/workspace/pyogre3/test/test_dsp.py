# ----------------------------------------------------------------
# test_dsp.py - Unit test program for Dsp
# ----------------------------------------------------------------
import ogre
import ogre_sig

import unittest
import logging
import logging.config
import select
import time
import os


# ----------------------------------------------------------------
class TestDsp(unittest.TestCase):

   def setUp(self):
      self.url = '%s://%s:%s' % (os.environ['OGRE_COMM'],
                                 os.environ['OGRE_NODE'],
                                 os.environ['OGRE_PORT'])
      self.dedicated_server = 'CdcBCPServer'

   def test_echo(self):
      proc = ogre.DspProcess(self.url, 'ogre_dsp1', self.dedicated_server)
      sig = ogre_sig.ogre_sync_req()
      sig.t1 = 47
      proc.send(sig)
      rsp = proc.receive()
      self.assertEqual(47, rsp.t1)
      proc.close()

   def test_multiple(self):
      proc1 = ogre.DspProcess(self.url, 'ogre_dsp1', self.dedicated_server)
      proc2 = ogre.DspProcess(self.url, 'ogre_dsp2', self.dedicated_server)

      sig = ogre_sig.ogre_sync_req()
      sig.t1 = 37
      proc2.send(sig)
      proc2.send(sig)

      count = 0
      for proc,sig in ogre.DspProcess.receive_any([proc1, proc2], timeout=1):
         print proc,sig
         self.assertEqual(37, sig.t1)
         count += 1
      self.assertEqual(2, count)
      
      proc1.close()
      proc2.close()


   def tearDown(self):
      pass


# ----------------------------------------------------------------      
if __name__ == '__main__':
   logging.config.fileConfig('testlog.ini')
   unittest.main()

# End of file
