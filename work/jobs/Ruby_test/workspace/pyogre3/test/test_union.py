# ----------------------------------------------------------------
# test_union.py - 
# ----------------------------------------------------------------
import ogre
import union_sig

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
      #logging.info('Using URL: %s' % (self.url))
      #self.conn = ogre.create(self.url, "testogre")


   def test_unions00(self):
       p = ogre.Process(self.url, 'ogre_proc')
       req = union_sig.TEST_UNION_REQ()
       req.c1 = 101
       req.s1 = 102
       
       req.msg1.value = 11
       req.msg1.info.data_size = 1
       req.msg1.info.data_array[0] = 41
       req.msg1.name[0] = 99
       req.msg1.foo.x = 97
       req.msg1.foo.y = 98
       req.msg1.foo.z = 99
       req.tag1 = 0

       req.msg2.value = 21
       req.msg2.info.data_size = 2
       req.msg2.info.data_array[0] = 51
       req.msg2.info.data_array[1] = 52
       req.msg2.name[0] = 99
       req.msg2.foo.x = 87
       req.msg2.foo.y = 88
       req.msg2.foo.z = 89
       req.tag2 = 0

       p.send(req)
       rsp = p.receive()

       self.assertEquals(101, rsp.c1)
       self.assertEquals(102, rsp.s1)
       self.assert_(rsp.tag1 == 0)
       self.assert_(rsp.msg1.value == 11)
       self.assert_(rsp.tag2 == 0)
       self.assert_(rsp.msg2.value == 21)
       self.assertEquals(0, rsp.err)

   def test_unions10(self):
       p = ogre.Process(self.url, 'ogre_proc')
       req = union_sig.TEST_UNION_REQ()
       req.c1 = 101
       req.s1 = 102

       req.msg1.value = 123
       req.msg1.info.data_size = 1
       req.msg1.info.data_array[0] = 47
       req.msg1.name[0] = 99
       req.msg1.foo.x = 97
       req.msg1.foo.y = 98
       req.msg1.foo.z = 99
       req.tag1 = 1

       req.msg2.value = 21
       req.msg2.info.data_size = 2
       req.msg2.info.data_array[0] = 1
       req.msg2.info.data_array[1] = 2
       req.msg2.name[0] = 99
       req.msg2.foo.x = 87
       req.msg2.foo.y = 88
       req.msg2.foo.z = 89
       req.tag2 = 0

       p.send(req)
       rsp = p.receive()

       self.assertEquals(101, rsp.c1)
       self.assertEquals(102, rsp.s1)
       self.assert_(rsp.tag1 == 1)
       self.assert_(rsp.msg1.info.data_array == [47, 0, 0, 0, 0, 0, 0, 0])
       self.assert_(rsp.tag2 == 0)
       self.assert_(rsp.msg2.value == 21)
       self.assertEquals(0, rsp.err)

   def test_unions20(self):
       p = ogre.Process(self.url, 'ogre_proc')
       req = union_sig.TEST_UNION_REQ()
       req.c1 = 101
       req.s1 = 102

       req.msg1.value = 123
       req.msg1.info.data_size = 1
       req.msg1.info.data_array[0] = 31
       req.msg1.name[0] = 0x61
       req.msg1.name[1] = 0x62
       req.msg1.name[2] = 0x63
       req.msg1.foo.x = 97
       req.msg1.foo.y = 98
       req.msg1.foo.z = 99
       req.tag1 = 2

       req.msg2.value = 21
       req.msg2.info.data_size = 2
       req.msg2.info.data_array[0] = 1
       req.msg2.info.data_array[1] = 2
       req.msg2.name[0] = 99
       req.msg2.foo.x = 87
       req.msg2.foo.y = 88
       req.msg2.foo.z = 89
       req.tag2 = 0

       p.send(req)
       rsp = p.receive()

       self.assertEquals(101, rsp.c1)
       self.assertEquals(102, rsp.s1)
       self.assert_(rsp.tag1 == 2)
       self.assert_(rsp.msg1.name[0] == 0x61)
       self.assert_(rsp.msg1.name[1] == 0x62)
       self.assert_(rsp.msg1.name[2] == 0x63)
       self.assert_(rsp.tag2 == 0)
       self.assert_(rsp.msg2.value == 21)
       self.assertEquals(0, rsp.err)

   def test_unions30(self):
       p = ogre.Process(self.url, 'ogre_proc')
       req = union_sig.TEST_UNION_REQ()
       req.c1 = 101
       req.s1 = 102

       req.msg1.value = 123
       req.msg1.info.data_size = 1
       req.msg1.info.data_array[0] = 31
       req.msg1.name[0] = 0x61
       req.msg1.name[1] = 0x62
       req.msg1.name[2] = 0x63
       req.msg1.foo.x = 97
       req.msg1.foo.y = 98
       req.msg1.foo.z = 99
       req.tag1 = 2

       req.msg2.value = 21
       req.msg2.info.data_size = 2
       req.msg2.info.data_array[0] = 1
       req.msg2.info.data_array[1] = 2
       req.msg2.name[0] = 99
       req.msg2.foo.x = 87
       req.msg2.foo.y = 88
       req.msg2.foo.z = 89
       req.tag2 = 100

       p.send(req)
       rsp = p.receive()

       self.assertEquals(101, rsp.c1)
       self.assertEquals(102, rsp.s1)
       self.assert_(rsp.tag1 == 2)
       self.assert_(rsp.msg1.name[0] == 0x61)
       self.assert_(rsp.msg1.name[1] == 0x62)
       self.assert_(rsp.msg1.name[2] == 0x63)
       self.assert_(rsp.tag2 == 100)
       self.assert_(rsp.msg2.foo.x == 87)
       self.assert_(rsp.msg2.foo.y == 88)
       self.assert_(rsp.msg2.foo.z == 89)
       self.assertEquals(0, rsp.err)

   def tearDown(self):
      pass


# ----------------------------------------------------------------      
if __name__ == '__main__':
   logging.config.fileConfig('testlog.ini')
   unittest.main()

# End of file
