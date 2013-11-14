#!/bin/env ruby
$: << File.dirname(__FILE__)
$: << File.join(File.dirname(__FILE__), "..", "lib")
#require 'pp'
require 'user'
require 'front'
require 'fparser'

#
# This a C function parser.
#
# Expected input is signal description files written in C (usually with 
# .h and .sig extensions).
# 

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
association_table, constant_table, preprocessed_header_files, include_table = Front.process_header_files()
puts "Finished\n"

#
# Phase 2   Parse C header files and generate tables where all necessary
#           information is collected
#
puts "\nPHASE 2: C header file parsing"
tables = Front.cparse(preprocessed_header_files)
puts "Finished\n"
#pp tables

#
# Phase 3   Generate C function executor
#
puts "\nPHASE 3: C function file"
fparser = Fparser.new()
fparser.generate_files(tables[0], include_table)
puts "Finished\n"
