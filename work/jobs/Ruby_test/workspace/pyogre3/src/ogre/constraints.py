#
# Constraints 
#   (c) 2003 Tero Saarni
#
# Description:
#   Provides easier mechanism to compare signal data
#

"""
Constraints is a small helper module for comparing the data of received
signal to a 'template' of a signal. The basic idea is taken from TTCN
but it's likely it exists also in other systems.

The idea is that instead of comparing each signal attribute separately
like (assuming you are using unittest and failUnless()): ::

    self.failUnless(replysig.a == 123)
    self.failUnless(replysig.b > 10)
    self.failUnless(replysig.c < 20)

it's possible to define constraints encapsulating the comparison operations: ::

    constraint = SomeSignal()
    constraint.a = EQ(123)
    constraint.b = GT(10)
    constraint.c = LT(20)

and then use the constraint: ::

    self.failUnless(replysig == constraint)

The equality operator is overloaded to execute appropriate comparisons
to each data attribute.

The comparison operators in ose.constraints module are:

    - ANY()      comparison returns True for any value
    - LT(val)    True if the compared value is Less Than 'val'
    - LE(val)    True if the compared value is Less or Equal as 'val'
    - EQ(val)    True if the compared value is EQual to 'val'
    - NE(val)    True if the compared value is Not Equal to 'val'
    - GT(val)    True if the compared value is Greater Than 'val'
    - GE(val)    True if the compared value is Greater or Equal as 'val'

In addition following operators are available

    - NOT(op)       Inverts the result of 'op'
    - AND(op1, op2) True if both 'op1' and 'op2' are true
    - OR(op1, op2)  True if 'op1' or 'op2' is true

These operator objects are assigned as signal attributes for a signal
that is wrapped to Constraint object.

If the test 'replysig == constraint' fails (i.e. some of the constrained
attributes didn't evaluate to True) you might want to get some clue of
which of the attributes didn't match with the constraint. Currently you
cannot get detailed feedback from the comparison but one solution is to
print the signal object and constraint when comparison fails. TestCase's
failUnless() method has optional second parameter after the comparison
expression which is a message giving detailed reason for failure: ::

    self.failUnless(self.sig==self.constr, '%s\\n%s' % (self.sig, self.constr))

When the comparison fails backtrace will contain something like: ::

    AssertionError: <osesig sigNo=10007 name=ConstraintTestSig data=
    {'a': 1, 'b': 3} at 0x2aff08>
    <osesig sigNo=10007 name=ConstraintTestSig data=
    {'a': LT(2), 'b': EQ(4)} at 0x2a17b0>

Here you can see that the received signal contains 3 as a value of 'b'.
On the other hand the constraint expected that 'b' would be equal to 4.

Usage: ::

    constr = TestReq()
    constr.a = ANY()
    constr.b = NE(3)
    constr.c = AND(GT(15), LT(25))

    somesig = ose.receive(ose.SigSelect([TestReq.SIGNO]))
    if somesig == constr:
        ...
    else:
        print 'wrong attribute values in signal: ' + str(somesig)
"""


class Operator:
    """
    Description:
        Operator is base class for comparison operators, defined mainly just
        for common __str__ and __repr__ method for printing operators.
    """
    def __init__(self, value=None):
        self.value = value

    def __str__(self):
        if self.value is not None:
            msg = '%s(%s)' % (self.__class__.__name__, str(self.value))
        else:
            msg = self.__class__.__name__
        return msg

    __repr__  = __str__



class ANY(Operator):
    """Matches with ANYthing"""
    def __eq__(self, other):
        return True

class LT(Operator):
    """Less Than"""
    def __eq__(self, other):
        return other < self.value

class LE(Operator):
    """Less or Equal than"""
    def __eq__(self, other):
        return other <= self.value

class EQ(Operator):
    """EQual to"""
    def __eq__(self, other):
        return other == self.value

class NE(Operator):
    """Not Equal to"""
    def __eq__(self, other):
        return other != self.value

class GT(Operator):
    """Greater Than"""
    def __eq__(self, other):
        return other > self.value

class GE(Operator):
    """Greater or Equal than"""
    def __eq__(self, other):
        return other >= self.value



class NOT(Operator):
    def __eq__(self, other):
        return not other == self.value



class AND(Operator):
    def __init__(self, op1, op2):
        Operator.__init__(self)
        self.op1 = op1
        self.op2 = op2

    def __eq__(self, other):
        return (other == self.op1) and (other == self.op2)

    def __str__(self):
        return 'AND(%s,%s)' % (str(self.op1), str(self.op2))

class OR(Operator):
    def __init__(self, op1, op2):
        Operator.__init__(self)
        self.op1 = op1
        self.op2 = op2

    def __eq__(self, other):
        return (other == self.op1) or (other == self.op2)

    def __str__(self):
        return 'OR(%s,%s)' % (str(self.op1), str(self.op2))
