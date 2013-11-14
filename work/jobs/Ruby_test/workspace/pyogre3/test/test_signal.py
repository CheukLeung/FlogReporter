# ----------------------------------------------------------------
# test_signal.py - Unit test program for signals 
# ----------------------------------------------------------------

# = Test Case 
# - [VS OGRE.FOO.BAR.PYTHON] FOO_BAR_SLOGAN
#
# = Description
# What is verified by this test?
# 
# = Requirement 
# - [RS OGRE.FOO.BAR] FOO_BAR_SLOGAN
#
# = Action / Event
# ==== Action:
# <How is the test performed>
# e.g. Create the process ogre_proc. Create the signal Ogre_align_reg
# and initialize its content members. Send the signal to the 
# ogre_proc process and await reply.
# ==== Expected result:
# <Define PASSED/FAILED>
# e.g. PASSED if the received signal content is as initialized before
# sent.
#
# = Communication and hosts:
# - Perform the test using OSEGW on Linux and Solaris.
# - Perform the test using LINX on Linux.
#
# = Comment
# Nothing to say..

import ogre

import base_type_sig
import company

import unittest
import logging
import logging.config
import os

# ----------------------------------------------------------------
class TestBaseTypes(unittest.TestCase):

   def setUp(self):
      self.url = '%s://%s:%s' % (os.environ['OGRE_COMM'],
                                 os.environ['OGRE_NODE'],
                                 os.environ['OGRE_PORT'])
      self.conn = ogre.create(self.url, "testogre")
      #logging.info('Using URL: %s' % (self.url))


   def test_signo(self):
      sig = company.HAIR_SIG()

      self.conn.hunt("ogre_echo")
      pid = self.conn.receive().sender()
      self.assertNotEqual(pid, 0);

      self.conn.send(sig, pid)
      reply = self.conn.receive()

      self.assertEqual(company.HAIR_SIG.SIGNO, reply.sigNo)

      sig = company.TEST_SIG()
      sig.halvar = -45
      sig.sentinel = -7
      
      self.conn.send(sig, pid)
      reply = self.conn.receive()

      self.assertEqual(company.TEST_SIG.SIGNO, reply.sigNo)
      self.assertEqual(-45, reply.halvar)
      self.assertEqual(-7, reply.sentinel)

      sig = company.POI_SIG()
      sig.poison = 0xcafebabe

      self.conn.send(sig, pid)
      reply = self.conn.receive()

      self.assertEqual(company.POI_SIG.SIGNO, reply.sigNo)
      self.assertEqual(0xcafebabe, reply.poison)

   def test_compare(self):
      self.conn.hunt("ogre_echo")
      pid = self.conn.receive().sender()
      self.assertNotEqual(pid, 0);

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint1 = 1234567
      sig.sint1 = -23456
      sig.uint2 = 23456
      sig.sint2 = -1234
      sig.uint3 = 47
      sig.sint3 = -99

      sig.uint4 = 1234567
      sig.sint4 = -23456
      sig.uint5 = 23456
      sig.sint5 = -1234
      sig.uint6 = 47
      sig.sint6 = -99

      self.conn.send(sig, pid)
      reply = self.conn.receive()

      self.assertEqual(sig, reply)
      self.assertNotEqual(sig, None)
      sig.sint5 = 43
      self.assertNotEqual(sig, reply)
      sig.sint5 = -1234
      self.assertEqual(sig, reply)
      sig.nisse = 7
      self.assertEqual(sig, reply)

   def test_normal(self):
      self.conn.hunt("ogre_echo")
      pid = self.conn.receive().sender()
      self.assertNotEqual(pid, 0);

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint1 = 1234567
      sig.sint1 = -23456
      sig.uint2 = 23456
      sig.sint2 = -1234
      sig.uint3 = 47
      sig.sint3 = -99

      sig.uint4 = 1234567
      sig.sint4 = -23456
      sig.uint5 = 23456
      sig.sint5 = -1234
      sig.uint6 = 47
      sig.sint6 = -99

      # NOTE, enums does not work OK
      #sig.e1 = BASE_TYPE_SIG::Etype.BAR
      sig.e1 = 1
      #sig.b1 = 0
      #sig.b2 = 1

      self.conn.send(sig, pid)
      reply = self.conn.receive()
      #self.assertEqual(sig, reply)

      # Verify the reply
      self.assertEqual(1234567,reply.uint1)
      self.assertEqual(-23456, reply.sint1)
      self.assertEqual(23456, reply.uint2)
      self.assertEqual(-1234, reply.sint2)
      self.assertEqual(47,    reply.uint3)
      self.assertEqual(-99,   reply.sint3)

      self.assertEqual(1234567,reply.uint4)
      self.assertEqual(-23456, reply.sint4)
      self.assertEqual(23456, reply.uint5)
      self.assertEqual(-1234, reply.sint5)
      self.assertEqual(47,    reply.uint6)
      self.assertEqual(-99,   reply.sint6)


   def test_min_max(self):
      self.conn.hunt("ogre_echo")
      pid = self.conn.receive().sender()
      self.assertNotEqual(pid, 0);

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint1 = 0
      sig.sint1 = 0x7fffffff
      sig.uint2 = 0
      sig.sint2 = 0x7fff
      sig.uint3 = 0
      sig.sint3 = 0x7f

      sig.uint4 = 0
      sig.sint4 = 0x7fffffff
      sig.uint5 = 0
      sig.sint5 = 0x7fff
      sig.uint6 = 0
      sig.sint6 = 0x7f

      sig.e1 = 1
      sig.b1 = 0
      sig.b2 = 1

      self.conn.send(sig, pid)
      reply = self.conn.receive()
      #self.assertEqual(sig, reply)

      # Verify the reply
      self.assertEqual(0,          reply.uint1)
      self.assertEqual(2147483647, reply.sint1)
      self.assertEqual(0,     reply.uint2)
      self.assertEqual(32767, reply.sint2)
      self.assertEqual(0,     reply.uint3)
      self.assertEqual(127,   reply.sint3)

      self.assertEqual(0,          reply.uint4)
      self.assertEqual(2147483647, reply.sint4)
      self.assertEqual(0,     reply.uint5)
      self.assertEqual(32767, reply.sint5)
      self.assertEqual(0,     reply.uint6)
      self.assertEqual(127,   reply.sint6)

      self.assertEqual(1, reply.e1)
      self.assertEqual(0, reply.b1)
      self.assertEqual(1, reply.b2)

      
   def test_max_min(self):
      self.conn.hunt("ogre_echo")
      pid = self.conn.receive().sender()
      self.assertNotEqual(pid, 0);

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint1 = 0xffffffff
      sig.sint1 = -2147483648
      sig.uint2 = 0xffff
      sig.sint2 = -32768
      sig.uint3 = 0xff
      sig.sint3 = -128

      sig.uint4 = 0xffffffff
      sig.sint4 = -2147483648
      sig.uint5 = 0xffff
      sig.sint5 = -32768
      sig.uint6 = 0xff
      sig.sint6 = -128

      sig.e1 = 2
      sig.b1 = 1
      sig.b2 = 0

      self.conn.send(sig, pid)
      reply = self.conn.receive()
      #self.assertEqual(sig, reply)

      # Verify the reply
      self.assertEqual(0xffffffff, reply.uint1)
      self.assertEqual(-2147483648, reply.sint1)
      self.assertEqual(0xffff, reply.uint2)
      self.assertEqual(-32768, reply.sint2)
      self.assertEqual(0xff,   reply.uint3)
      self.assertEqual(-128,   reply.sint3)

      self.assertEqual(0xffffffff, reply.uint4)
      self.assertEqual(-2147483648, reply.sint4)
      self.assertEqual(0xffff, reply.uint5)
      self.assertEqual(-32768, reply.sint5)
      self.assertEqual(0xff,   reply.uint6)
      self.assertEqual(-128,   reply.sint6)

      self.assertEqual(2, reply.e1)
      self.assertEqual(1, reply.b1)
      self.assertEqual(0, reply.b2)


   def test_err(self):
      self.conn.hunt("ogre_echo")
      pid = self.conn.receive().sender()

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint1 = -2
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.sint1 = -2147483649
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint2 = -1
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.sint2 = -32769
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint3 = -1
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.sint3 = -129
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint4 = -2
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.sint4 = -2147483649
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint5 = -1
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.sint5 = -32769
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint6 = -1
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.sint6 = -129
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint1 = 0x100000000
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.sint1 = 2147483648
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint2 = 0x10000
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.sint2 = 32768
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint3 = 0x100
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.sint3 = 128
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint4 = 0x100000000
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.sint4 = 2147483648
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint5 = 0x10000
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.sint5 = 32768
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.uint6 = 0x100
      self.assertRaises(ValueError, self.conn.send, sig, pid)

      sig = base_type_sig.BASE_TYPE_SIG()
      sig.sint6 = 128
      self.assertRaises(ValueError, self.conn.send, sig, pid)


      
   def tearDown(self):
      self.conn.close()
      pass


# ----------------------------------------------------------------      
if __name__ == '__main__':
   logging.config.fileConfig('testlog.ini')
   #logging.getLogger('ogre').setLevel(logging.DEBUG)
   unittest.main()

# End of file
