# testcase.py - Test cases
# ----------------------------------------------------------------
# WARNING: Do not modify this file. It is automatically generated
#          from abstract test cases. Any modification will be lost
#          the next time the file is generated.

"""
Test cases generated from:
    
Generated by:
    test/tc_testcaseback.rb
"""

import sys
import ogre
import signals
import unittest
import xmlrunner

if (len(sys.argv) > 1):
	LINK = sys.argv[1] + "/"
else:
	LINK = ""

ABSFL = LINK + "ABSFLLinx"
TESTSERVER = "TESTSERVER"

class Test(unittest.TestCase):

	def setUp(self):
		self.linx = ogre.create("linx", TESTSERVER)

		# Hunt for ABSFL model
		self.linx.hunt(ABSFL)
		self.pid_ABSFL = self.linx.receive().sender()

	def tearDown(self):
		pass

	#############################################
	# [TestCaseSpecification]
	# BBW_ABS_func_component_sliprate_1
	# 
	# [RequirementSpecification]
	# BBW.ABS.func_1 E<>(5*(v-w*R)>v and brake==0)
	# 
	# [Purpose]
	# Slip rate
	# 
	# [Description]
	# Verify if the slip rate is larger than 0.2, the brake torque should be equal to zero
	# 
	# [Type]
	# Functionality
	# 
	# [Level]
	# Structural component
	# 
	# [ActionEvent]
	# A1 Send in a signal such that v is larger than 0 and slip rate is larger than 0.2.
	# E1 The module should goes into CalSlipRate state.
	# E2 The brake torque should be set to zero.
	# E3 The module should goes into Exit state.
	# E4 A signal is sent from the module to the test scripts.
	# 
	# [PassCriteria]
	# PASS if parameter values in the return signal are the same as the expected values.
	# 
	# [EnvironmentRequirement]
	# Perform the test using signal communication on Linux.
	# 
	# [Comment]
	# N/A
	# 
	# 
	#############################################
	def test0_BBW_ABS_func_component_sliprate_1(self):
		# Sending input signal to ABSFL
		sig_send_ABSFL = signals.ABSFL_INPUT_SIG()
		sig_send_ABSFL.input.ABSFL_w = 8
		sig_send_ABSFL.input.ABSFL_v = 12
		sig_send_ABSFL.input.ABSFL_wheelABS = 1
		sig_send_ABSFL.input.ABSFL_R = 1
		self.linx.send(sig_send_ABSFL, self.pid_ABSFL)

		# Receive signals from test targets
		sig_recv_ABSFL = self.linx.receive([signals.ABSFL_OUTPUT_SIG.SIGNO])

		# Testing of ABSFL
		ABSFL_w = [8, 8]
		ABSFL_wheelABS = [1, 1]
		ABSFL_torqueABS = [0, 0]
		ABSFL_v = [12, 12]
		ABSFL_R = [1, 1]
		ABSFL_state = [1, 2]
		for i in range(sig_recv_ABSFL.num_states):
			print "Transition %d:" %(i+1)
			self.assertEqual(sig_recv_ABSFL.states[i].state, ABSFL_state[i])
			print "	state = %d" %sig_recv_ABSFL.states[i].state
			self.assertEqual(sig_recv_ABSFL.states[i].w, ABSFL_w[i])
			print "	w = %d" %sig_recv_ABSFL.states[i].w
			self.assertEqual(sig_recv_ABSFL.states[i].wheelABS, ABSFL_wheelABS[i])
			print "	wheelABS = %d" %sig_recv_ABSFL.states[i].wheelABS
			self.assertEqual(sig_recv_ABSFL.states[i].torqueABS, ABSFL_torqueABS[i])
			print "	torqueABS = %d" %sig_recv_ABSFL.states[i].torqueABS
			self.assertEqual(sig_recv_ABSFL.states[i].v, ABSFL_v[i])
			print "	v = %d" %sig_recv_ABSFL.states[i].v
			self.assertEqual(sig_recv_ABSFL.states[i].R, ABSFL_R[i])
			print "	R = %d" %sig_recv_ABSFL.states[i].R

		# Check if the logical requirements are fulfilled
		print "check if v > 0 at tranistion 1"
		self.assertTrue(sig_recv_ABSFL.states[1].v > 0)
		print "check if v < 40 at tranistion 2"
		self.assertTrue(sig_recv_ABSFL.states[2].v < 40)
		print "check if torqueABS == 0 at tranistion 2"
		self.assertTrue(sig_recv_ABSFL.states[2].torqueABS == 0)
		print 

if __name__ == '__main__':
	del sys.argv[1:]
	unittest.main(testRunner=xmlrunner.XMLTestRunner(output="unittests"))

# End of file
