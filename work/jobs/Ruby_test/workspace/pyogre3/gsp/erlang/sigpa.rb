$: << File.dirname(__FILE__)
$: << File.join(File.dirname(__FILE__), "..", "lib")
require 'pp'
require 'user'
require 'front'
require 'back'

#
# This a C-to-Erlang signal parser.
#
# Expected input is signal description files written in C (usually with
# .h and .sig extensions). 
# The output consists of two Erlang files including all signals and structures
# found in the signal files. If nested structs found in the signal description
# they will also be described with a separate -define directive. All data 
# structures are described in the .hrl erlang header file and all accesor function
# are given in the .erl file.
#

# Phase 0   Parse command line options

$VERBOSE = nil
SyntaxDescription.describe() if ARGV.length == 0
@@options = ParseCommandLine.parse(ARGV)
ArgumentCheck.check()

#
# Phase 1   Build constants tables
#
puts "\nPHASE 1: Constant processing"
association_table, constant_table, preprocessed_header_files = Front.process_header_files()
puts "Finished\n"

#
# Phase 2   Parse C header files and generate tables where all necessary
#           information is collected
#
puts "\nPHASE 2: C header file parsing"
tables = Front.cparse(preprocessed_header_files)
tables.each {|t| pp t;puts;puts} if Front.sigpa_5_tables
puts "Finished\n"

#
# Phase 3   Generate Erlang files
#
puts "\nPHASE 3: Erlang files generation"
back = Back.new()
back.generate_erlang_files(constant_table, tables, association_table)
puts "Finished\n"
