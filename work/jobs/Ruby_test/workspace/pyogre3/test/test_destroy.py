# ----------------------------------------------------------------
# test_target.py - Test cases that requires a target connection
# ----------------------------------------------------------------
import ogre
import ogre_sig
import array_sig
import signals

import unittest
import logging
import logging.config
import select
import time
import timeit
import os


# ----------------------------------------------------------------
class TestTarget(unittest.TestCase):

   def setUp(self):
      self.url = '%s://%s:%s' % (os.environ['OGRE_COMM'],
                                 os.environ['OGRE_NODE'],
                                 os.environ['OGRE_PORT'])
      #logging.info('Using URL: %s' % (self.url))


   def test_unpack_nested_array0(self):
      for i in range(1000):
         print "Connect to %s" % self.url
         conn = ogre.create(self.url, "testogre")
         #conn.close()
         time.sleep(0.010)


   def tearDown(self):
      #self.conn.close()
      pass


# ----------------------------------------------------------------      
if __name__ == '__main__':
   logging.config.fileConfig('testlog.ini')
   unittest.main()

# End of file
