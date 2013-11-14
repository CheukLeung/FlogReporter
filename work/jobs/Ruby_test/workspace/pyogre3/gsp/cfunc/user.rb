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
   ruby #{$0} <options> <header_files>

Description:
   OGRE Signal parser and C function generator.

   Options:

   --cpp <cpp_path>
           Alternative path to cpp. Default, if omitted, is
           /usr/lib/cpp for Solaris and /usr/bin/cpp for Linux.

   -I <include_directory>
           Include directory for cpp. This option can be
           repeated to specify different directories.

   -i <include_file>
           Include file for cpp. This option can be
           repeated to specify different files.

   -D<MACRO> 
   -D<MACRO>=<value>
           Define macros for cpp. (See man page for cpp).
           This option can be repeated to specify different
           macros.

   -o <outfile>
           Name of output file (only name part, extensions .h and .c 
           will be assigned automatically). If omitted, will default 
           to the name of the signal file.

   -h      Prints this help text.

   -v      Verbose mode.

   -d      Debug mode. When this flag is set, a zip file named 
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
    options.include_paths = []
    options.include_files = []
    options.header_files = []
    options.signal_files = []
    options.directory = Dir.getwd
    options.macros = []
    options.outfile = ""
    options.help = false
    options.verbose = false
    options.debug = false

    opts = OptionParser.new do |opts|

      opts.on("--cpp S", String) do |s|
        options.cpp = s
        if s =~ /\s/
          ind = options.args.index(s)
          options.args[ind] = "'" + options.args[ind] + "'"
        end
      end

      opts.on("-I S", String) do |s|
        dirarr = s.split
        dirarr.each {|d| options.include_paths.insert(-1, d)}
      end

      opts.on("-i S", String) do |s|
        filarr = s.split
        filarr.each {|f| options.include_files.insert(-1, f)}
      end

      opts.on("-D M", String) do |m|
        options.macros.insert(-1, m)
      end

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
    options.header_files = opts.parse!(argv)
    options.header_files.collect!{|f| File.expand_path(f)}
    options
  end

end

#
# Performs a check of user provided arguments 
#
class ArgumentCheck

  def self.check

    SyntaxDescription.describe() if @@options.help == true || (@@options.header_files.length == 0)

    # Check cpp
    if not @@options.cpp.empty?
      file = @@options.cpp.split[0]
      raise ArgumentError, "Cannot execute #{@@options.cpp}\n" unless File.executable?(file)
    else
      if Config::CONFIG["host_os"].downcase =~ /solaris/
        @@options.cpp = "/usr/lib/cpp"
      elsif Config::CONFIG["host_os"].downcase =~ /linux/
        @@options.cpp = "/usr/bin/cpp"
      else
        raise RuntimeError, "Unsupported host OS\n"
      end
    end

    # Check macros. Assign 1 to macros defined only as names.
    @@options.macros.each do |macro|
      macro << "=1" if macro !~ /\=/
    end

    # Check header files
    @@options.header_files.each {|f| raise ArgumentError, "Cannot open #{f}\n" unless File.readable?(f)}

    # Establish which of the header files are signal files (Usually just the one)
    @@options.header_files.each do |filename|
      File.open(filename, "r") do |f|
        farr = f.readlines
        farr.each do |row|
          if row =~ (/\/\* *!- *SIGNO\s*\(.+\) *-! *\*\/\s*$/)
            @@options.signal_files << filename
            break
          end
        end
      end
    end

    # Set name of output file
    if @@options.outfile.empty?
      @@options.outfile = @@options.directory + "/" +  @@options.signal_files[-1].split('/')[-1]
    end
    if @@options.outfile =~ /\./
      @@options.outfile = $`
    end

    # Check include paths
    @@options.include_paths.each {|i| puts "Warning: Non-existent include path #{i}\n" unless File.exists?(i)}

  end
end

#
# Print options
#
class Printoptions

  def self.list
    puts "@@options.args= ", @@options.args, "\n"
    puts "@@options.cpp= ", @@options.cpp
    puts "@@options.include_paths= ", @@options.include_paths
    puts "@@options.include_files= ", @@options.include_files
    puts "@@options.header_files= ", @@options.header_files
    puts "@@options.signal_files= ", @@options.signal_files
    puts "@@options.macros= ", @@options.macros
    puts "@@options.outfile= ", @@options.outfile
    puts "@@options.help= ", @@options.help
    puts "@@options.verbose= ", @@options.verbose
    puts "@@options.debug= ", @@options.debug
  end

end
