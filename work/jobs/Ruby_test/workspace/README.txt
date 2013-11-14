--------------------------------------------------------------------
---                  Abstract test case parser                   ---
--------------------------------------------------------------------


-Introduction-
This project implements a parser that can parse formatted abstract test cases
and convert them to concrete, executable test cases in Python format. The design
is part of the EAST-ADL tailored testing and the product test cases should be 
run against production code to verify the behaviour of it.

In a successful execution, the following files should be generated:
  1. Siganl header in C (signals.sig)
  2. Siganl header in Python (signals.py)
  3. Concrete test cases (default: testcase.py)
  4. Type definition (type.h)

N.B. Type definition is generated for a 32-bit Linux machine and may be unusable
     in other machine. 

-Design-
The Brake-by-wire application is designed around 5 components:
  1. Main (testpa/python/testpa.rb)
  2. Grammar book (testpa/lib/TCrubyparser.y)
  3. Front-end (testpa/lib/front.rb)
  4. Back-end (testpa/python/testcaseback.rb) 
  5. Farkle signal parser (sigpa)

Main: 
Control the flow of the parsing by first running the front-end and pass the 
results to the back-end.

Grammar book:
Define how the abstract test case should be extracted to useful information.

Front-end:
Concate and trim the input files for parsing

Back-end:
Generate signal header in C and concrete test cases in Python.

Farkle signal parser:
Parse the C siganl header to Python.

-Environmental prerequsites-
 - Linux
 - Ruby
 
-Prerequsites for running the resulting test case-
 - Python (with modules: ogre, unittest, xmlrunner)
 - LINX (tested with version 2.5.1), see:
   http://linx.sourceforge.net/linxdoc/doc/index.html

-Test Instruction-
sh makeTestcase.sh <abstract testcase 0> <abstract testcase 1> .. -o <output>
python <output>

