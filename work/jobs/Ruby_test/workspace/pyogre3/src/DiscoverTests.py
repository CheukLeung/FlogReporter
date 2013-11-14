#!/bin/env python
import unittest
import sys



test = __import__(sys.argv[1][:-3])
tests = []
testers = {}

for aTest in dir(test):
	if aTest[0] != '_':
		tests.append(aTest)

t = unittest.TestLoader()
for aTest in tests:
	tmp = t.getTestCaseNames(getattr(test, aTest))
	if len(tmp) != 0:
		testers[aTest] = tmp

for key,values in testers.items():
	print key + ":",
	for value in values:
		print value + ",",
	print ""
