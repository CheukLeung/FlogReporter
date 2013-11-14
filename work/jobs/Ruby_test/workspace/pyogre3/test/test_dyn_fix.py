# ----------------------------------------------------------------
# test_dyn_fix.py - 
# ----------------------------------------------------------------
import ogre
import dyn_fix_sig

import unittest
import logging
import logging.config
import os


# ----------------------------------------------------------------
class TestUnion(unittest.TestCase):

   def setUp(self):
      self.url = '%s://%s:%s' % (os.environ['OGRE_COMM'],
                                 os.environ['OGRE_NODE'],
                                 os.environ['OGRE_PORT'])
      self.p = ogre.Process(self.url, 'ogre_proc')

   def test_dyn_fix_array_1(self):
      """
      Verifies an array of struct with dynamic and fix arrays
      """
      sig = dyn_fix_sig.OgreDynFix1Req()
      sig.f1 = 101

      self.p.send(sig)
      sig2 = self.p.receive()

      self.assertEquals(0, sig2.err)
      self.assertEquals(101,  sig2.f1)
      self.assertEquals(4,  len(sig2.msg1))
      print sig2


   def test_dyn_fix_array_2(self):
      """
      Verifies an array of struct with dynamic and fix arrays
      """
      sig = dyn_fix_sig.OgreDynFix2Req()
      sig.f2 = 102

      self.p.send(sig)
      sig2 = self.p.receive()

      self.assertEquals(0, sig2.err)
      self.assertEquals(102,  sig2.f2)
      self.assertEquals(1,  len(sig2.msg2))
      print sig2


   def test_dyn_fix_array_3(self):
      """
      Verifies an array of struct with dynamic and fix arrays
      """
      sig = dyn_fix_sig.OgreDynFix3Req()
      sig.f3 = 103

      sig.msg3 = [ 9, 8 ]
      sig.msg4 = [ 3, 4, 5 ]

      self.p.send(sig)
      sig2 = self.p.receive()

      self.assertEquals(0, sig2.err)
      self.assertEquals(103,  sig2.f3)
      self.assertEquals(2,  len(sig2.msg3))

      self.assertEquals(9,  sig2.msg3[0])
      self.assertEquals(8,  sig2.msg3[1])
      print sig2


   def test_dyn_fix_array_4(self):
      """
      Verifies an array of struct with dynamic and fix arrays
      """
      sig = dyn_fix_sig.OgreDynFix4Req()
      sig.f4 = 104

      sig.msg4 = [ 3, 4, 5 ]

      self.p.send(sig)
      sig2 = self.p.receive()

      self.assertEquals(0, sig2.err)
      self.assertEquals(104,  sig2.f4)
      self.assertEquals(3,  len(sig2.msg4))

      self.assertEquals(3,  sig2.msg4[0])
      self.assertEquals(4,  sig2.msg4[1])
      self.assertEquals(5,  sig2.msg4[2])
      print sig2


   def tearDown(self):
      self.p.close()


# ----------------------------------------------------------------      
if __name__ == '__main__':
   logging.config.fileConfig('testlog.ini')
   unittest.main()

# End of file
