require 'rbconfig'
require 'optparse'
require 'ostruct'

@@options = {}

#
#
# Display syntax description and exit
#
class SyntaxDescription

  def self.describe()
    puts <<END_OF_SYNTAX

Syntax:

   ruby #{$0} [<options>] <files> ...

Description:
   Abstract test case parser for Python.

Options:
   -o <outfile>
           Name of output file. If no extension is given, the 
           generated test case will be named "testcase.py"

   -h      Prints this help text.

   -v      Verbose mode.

   -d      Debug mode. When this option is set, a zip file named 
           debug_files.zip will be created, containing input files
           and intermediate files generated during the parsing process.
           
END_OF_SYNTAX
    exit
  end

end 


#
# Parse command line
#

class ParseCommandLine

  def self.parse(argv)
    options = OpenStruct.new
    options.args = argv.clone
    options.cpp = ""
    options.outfile = ""
    options.directory = Dir.pwd
    options.help = false
    options.verbose = false
    options.debug = false

    opts = OptionParser.new do |opts|

      opts.on("-o S", String) do |s|
        options.outfile = s
      end

      opts.on("-h", "--help") do
        options.help = true
      end

      opts.on("-v", "--verbose") do
        options.verbose = true
      end

      opts.on("-d", "--debug") do
        options.debug = true
      end

    end

    options.files = opts.parse!(argv)
    options.files.collect!{|f| File.expand_path(f)}
    options
  end

end

#
# Performs a check of user provided arguments 
#
class ArgumentCheck

  def self.check
    SyntaxDescription.describe() if @@options.help == true

    # Check that output file name has been given. Set extension to '.py', if none given.
    puts "WARNING: No output file name was given.\n" if @@options.outfile.empty?
    @@options.outfile = @@options.directory + "/" + @@options.args[-1].split(/\//)[-1].slice(0..-5) if @@options.outfile.empty?
    @@options.outfile << ".py" if @@options.outfile.split(/\//)[-1][-3,3] != ".py"
    
    # Check header files
    @@options.files.each {|f| raise ArgumentError, "Cannot open #{f}\n" unless File.readable?(f)}

  end

end

#
# Print options
#
class Printoptions

  def self.list
    puts "@@options.outfile= ", @@options.outfile
    puts "@@options.help= ", @@options.help
    puts "@@options.verbose= ", @@options.verbose
    puts "@@options.debug= ", @@options.debug
  end

end