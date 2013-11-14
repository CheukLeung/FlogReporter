################################################################
# Makefile - 
################################################################

SCRIPTS   = $(OGRE_HOME)/tools/scripts
SIG       = $(OGRE_HOME)/tools/test/sig
SIGPA     = $(OGRE_HOME)/generic/gsp/python/sigpa.rb
CLOC      = $(OGRE_HOME)/tools/scripts/cloc.pl
PYTHON    = env PYTHONPATH=../src python3.0

SIGNAL_FILES   = \
	ogre_sig.py \
	xxx_sig.py \
	union_sig.py \
	base_type_sig.py \
	typedef_sig.py \
	cdci_sig.py \
	dyn_fix_sig.py \
	company.py

.PHONY: all test clean

# ----------------------------------------------------------------
%.py: $(SIG)/%.sig
	ruby $(SIGPA) -i osetypes.h ogre_sig_dyn.h $^ -o $*

%.py: ../sig/%.sig
	ruby $(SIGPA) -i osetypes.h $^ -o $*

# ----------------------------------------------------------------
all: $(SIGNAL_FILES) test

test:
	$(PYTHON) suite.py

metrics:
	$(CLOC)	--by-file  ../src/ogre/*.py

coverage:
	$(PYTHON) coverage.py -e
	$(PYTHON) coverage.py -x suite.py
	$(PYTHON) coverage.py -r -o /afs

clean:
	-rm -rf $(SIGNAL_FILES)
	-rm -rf *.pyc

# End of file
