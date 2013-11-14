# ----------------------------------------------------------------      
# suite.py
# ----------------------------------------------------------------      

import test_constraints
import test_target
import test_process
import test_host
import test_pysigge
import test_signal
import test_union
import test_cdci

import unittest
import logging
import logging.config
import os


# ----------------------------------------------------------------      
def main():
   suite = unittest.TestSuite((
       unittest.makeSuite(test_constraints.TestConstraints, 'test'),
       unittest.makeSuite(test_target.TestTarget, 'test'),
#       unittest.makeSuite(test_host.TestHost, 'test'),
       unittest.makeSuite(test_process.TestProcess, 'test'),
       unittest.makeSuite(test_pysigge.TestPySigge, 'test'),
       unittest.makeSuite(test_signal.TestBaseTypes, 'test'),
       unittest.makeSuite(test_union.TestUnion, 'test'),
       unittest.makeSuite(test_cdci.TestUnion, 'test'),
       ))

   runner = unittest.TextTestRunner(verbosity=2)
   runner.run(suite)

# ----------------------------------------------------------------      
if __name__ == '__main__':
   logging.config.fileConfig('testlog.ini')
   #logging.getLogger('ogre').setLevel(logging.ERROR)
                           
   main()
   
# End of file
