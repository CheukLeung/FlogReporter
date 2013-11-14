#!/bin/env ruby

$: << File.dirname(__FILE__)
$: << File.join(File.dirname(__FILE__), "..", "lib")
require 'pp'
require 'testuser'
require 'front'
require 'testcaseback'

# This an abstract test case to concrete test case parser.
#
# Expected input is abstract test case written in following format:
#
# State:
# ( <module0>.<state0> <module1>.<state1> ...)
#
# <module0>.<param0>=<value0> <module0>.<param1>=<value1> ...
#
# Transitions:
# <module0>.<state0>-><module0>.<state1> {<logical expression>}
#
# Example:
# =============================================================================
# State:
# (BrakeSensor.Entry BrakeTorqueCalculator.idle WheelSensor.idle 
#  GlobalBrakeController.idle ABS.idle WheelActuator.idle)
#
# BrakeSensor.Pos=0 BrakeTorqueCalculator.maxBr=0 
# BrakeTorqueCalculator.ReqTorque=0 BrakeTorqueCalculator.Pos=0 
# WheelSensor.Rpm=0 GlobalBrakeController.Rpm=0 
# GlobalBrakeController.ReqTorque=0 GlobalBrakeController.WheelTorque=0 
# GlobalBrakeController.W=0 ABS.WABS=0 ABS.WheelTorqueABS=0 
# ABS.TorqueABS=0 ABS.v=0 ABS.s=0 WheelActuator.Torque=0 WheelActuator.brake=0 
#
# Transitions:
#  BrakeSensor.Entry->BrakeSensor.Exit { Pos := 0 }
# =============================================================================
#
# The output is a file containing signal declaration <signals.sig> in C format, 
# a predefined type file <type.h> and a test case in Python format.
#
# Phase 0   Parse command line
#
$VERBOSE = nil
SyntaxDescription.describe() if ARGV.length == 0
@@options = ParseCommandLine.parse(ARGV)
ArgumentCheck.check()

#
# Phase 1   Build constants tables
#
puts "\nPHASE 1: Constant processing"
preprocessed_files, comment_list = Front.process_files()
puts "Finished\n"

#
# Phase 2   Parse test case files and generate tables where all necessary
#           information is collected
#
puts "\nPHASE 2: Test case file parsing"
tables = Front.cparse(preprocessed_files)
puts "Finished\n"

#
# Phase 3   Generate test cases and signals file
#
puts "\nPHASE 3: Signal description generation"
testcaseback = TestCaseBack.new()
state_list, input_list, transitions_list, name_list = tables
testcaseback.generate_types_h()
testcaseback.generate_signals_sig(input_list[0])
testcaseback.generate_test_cases(tables, comment_list)


puts "Finished\n"
