#!/bin/env python

# Description:
#   Installation script for OGRE module. To install the module:
#
#     python setup.py install --home=<dir>
#
#   where <dir> is the base directory of install

from distutils.core import setup

setup(name = "pyogre",
      version = "7.3.0",
      description='OGRE 7, python 3, ver 0',
      author="Ulf Schroder",
      author_email="ulf.schroder@enea.com",
      url="http://ogre.enea.extern.sw.ericsson.se/",
      package_dir = {"": "src"},
      packages = ["ogre"],
      )

# End of file
