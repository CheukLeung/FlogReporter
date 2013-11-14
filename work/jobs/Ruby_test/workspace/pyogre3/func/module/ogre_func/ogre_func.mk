#osemain.con fragment
OSEMAINCON += $(REFSYSROOT)/modules/ogre_func/src/osemain.con
#object files for library
LIBOBJECTS += ogre_func.o
#Path to source code for $(LIBOBJECTS)
vpath %.c $(REFSYSROOT)/modules/ogre_func/src
#ogre_func library to include in kernel link module and load modules
LIBS += $(REFSYSROOT)/modules/ogre_func/$(LIBDIR)/libogre_func.a
LMLIBS += $(REFSYSROOT)/modules/ogre_func/$(LIBDIR)/libogre_func.a
