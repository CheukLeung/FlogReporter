$: << File.dirname(__FILE__)
$: << File.join(File.dirname(__FILE__), "..", "lib")
require 'pp'
require 'user'
require 'front'
require 'back'

#
# This a C-to-Perl signal parser.
#
# Expected input is signal description files written in C (usually with 
# .h and .sig extensions). 
# The output is a signal description file where the major part is hash
# containing the Perl equivalents to signal structs. Other parts include
# tables used to access signals by name and number.

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
# Phase 3   Generate Perl signal description file.
#
puts "\nPHASE 3: Signal description generation"
back = Back.new()
back.generate_signal_description(association_table, constant_table, tables)
puts "Finished\n"
