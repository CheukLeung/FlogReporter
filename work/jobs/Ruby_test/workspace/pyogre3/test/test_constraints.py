# ----------------------------------------------------------------
# test_constraints.py
# ----------------------------------------------------------------
from ogre.constraints import *
import ogre_sig

import unittest


# ----------------------------------------------------------------
class TestConstraints(unittest.TestCase):

   def setUp(self):
      pass


   def test_constraints(self):
      gold1 = ogre_sig.OGRE_SYNC_REQ()
      gold1.t1 = EQ(47)
      gold1.t2 = EQ(260)
      gold1.t3 = GT(10)
      gold1.t4 = AND(GT(1), LT(3))

      gold2 = ogre_sig.OGRE_SYNC_REQ()
      gold2.t1 = EQ(47)
      gold2.t2 = LT(250)
      gold2.t3 = GT(10)
      gold2.t4 = EQ(2)

      sig1 = ogre_sig.OGRE_SYNC_REQ()
      sig1.t1 = 47
      sig1.t2 = 260
      sig1.t3 = 12
      sig1.t4 = 2
      
      # Compare
      
      self.assertEqual(sig1, gold1,    "\n%s\n%s" % (sig1, gold1))
      self.assertNotEqual(sig1, gold2, "\n%s\n%s" % (sig1, gold2))

      
   def tearDown(self):
      pass


# ----------------------------------------------------------------      
if __name__ == '__main__':
   unittest.main()

# End of file
