# ----------------------------------------------------------------      
# suite.py - Run test cases
# ----------------------------------------------------------------      
import unittest
import os

# Include test scripts
import test_target
import test_print
import test_envvar

# ----------------------------------------------------------------      
# Create a test suite
suite = unittest.TestSuite((
   unittest.makeSuite(test_target.TestTarget, 'test'),
   unittest.makeSuite(test_print.TestPrint, 'test'),
   unittest.makeSuite(test_envvar.TestEnvvar, 'test'),
   ))

# Run the test suite
unittest.TextTestRunner(verbosity=2).run(suite)
   
# End of file
