# ----------------------------------------------------------------
# test_typedef.py - 
# ----------------------------------------------------------------
import ogre
import typedef_sig

import unittest
import logging
import logging.config
import os


# ----------------------------------------------------------------
class TestTypedef(unittest.TestCase):

   def setUp(self):
      self.url = '%s://%s:%s' % (os.environ['OGRE_COMM'],
                                 os.environ['OGRE_NODE'],
                                 os.environ['OGRE_PORT'])

   def test_union_in_array_1(self):
      """
      Verifies typedefed members in signals
      """
      p = ogre.Process(self.url, 'ogre_echo')
      sig = typedef_sig.typedef_sig()

      sig.testValue1 = 1
      sig.k1 = 2
      sig.k2 = 3
      sig.u1 = 4
      sig.u2 = 5
      sig.i1 = 6
      sig.i2 = 7
      sig.array1Size = 8

      sig.inner0.y1 = 9
      sig.inner0.y2 = 10

      sig.inner1.x1 = 11
      sig.inner1.x2 = 12
      sig.inner1.x3 = 13
      sig.inner1.x4 = 14
      sig.inner1.x5 = 15

      sig.inner2.x1 = 21
      sig.inner2.x2 = 22
      sig.inner2.x3 = 23
      sig.inner2.x4 = 24
      sig.inner2.x5 = 25

      sig.inner3.z1 = 31
      sig.inner3.z2 = 32

      sig.inner4[0].q1 = 101
      sig.inner4[0].q2 = 102
      sig.inner4[1].q1 = 111
      sig.inner4[1].q2 = 112


      p.send(sig)
      sig2 = p.receive()

      self.assertEqual(1, sig2.testValue1)
      self.assertEqual(2, sig2.k1)
      self.assertEqual(3, sig2.k2)
      self.assertEqual(4, sig2.u1)
      self.assertEqual(5, sig2.u2)
      self.assertEqual(6, sig2.i1)
      self.assertEqual(7, sig2.i2)
      self.assertEqual(8, sig2.array1Size)

      self.assertEqual(9, sig2.inner0.y1)
      self.assertEqual(10, sig2.inner0.y2)

      self.assertEqual(11, sig2.inner1.x1)
      self.assertEqual(12, sig2.inner1.x2)
      self.assertEqual(13, sig2.inner1.x3)
      self.assertEqual(14, sig2.inner1.x4)
      self.assertEqual(15, sig2.inner1.x5)

      self.assertEqual(21, sig2.inner2.x1)
      self.assertEqual(22, sig2.inner2.x2)
      self.assertEqual(23, sig2.inner2.x3)
      self.assertEqual(24, sig2.inner2.x4)
      self.assertEqual(25, sig2.inner2.x5)

      self.assertEqual(31, sig2.inner3.z1)
      self.assertEqual(32, sig2.inner3.z2)

      self.assertEqual(101, sig2.inner4[0].q1)
      self.assertEqual(102, sig2.inner4[0].q2)
      self.assertEqual(111, sig2.inner4[1].q1)
      self.assertEqual(112, sig2.inner4[1].q2)

      p.close()


   def tearDown(self):
      pass


# ----------------------------------------------------------------      
if __name__ == '__main__':
   logging.config.fileConfig('testlog.ini')
   unittest.main()

# End of file
