require 'rbconfig'
require 'optparse'
require 'ostruct'

@@options = {}
@@endian = ""

#
# Display syntax description and exit
#
class SyntaxDescription

  def self.describe()
    puts <<END_OF_SYNTAX

Syntax:

   ruby #{$0} <options> <header_files>

   Available options:

   --cpp <cpp_path>
           Alternative path to cpp. If omitted, is /usr/lib/cpp 
           for Solaris and /usr/bin/cpp for Linux.

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

   --directory <directory>
           Destination directory for generated Java classes.
           Has to exist, otherwise an error message is output.
           If omitted, defaults to the current directory.

   --interface <name>
           Name of optional Java interface the generated Java
           classes should implement.

   --package <name>
           Name of Java package the generated Java classes should
           belong to. If omitted, no package declaration is 
           generated. 

   --endian <big_or_little>
           Optional value of endianness to use: 'big' or 'little'
           If omitted, defaults to 'auto', i.e. the endianness
           of the host.

   -d      Debug mode. When this flag is set, a zip file named 
           debug_files.zip will be created, containing input files
           and intermediate files generated during the parsing process.

   -h      Prints syntax description.
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
    options.macros = []
    options.codefile = ""
    options.directory = Dir.getwd
    options.interface = ""
    options.package = ""
    options.endian = ""
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
        dirarr.each {|d| options.include_paths.insert(-1, File.expand_path(d))}
      end

      opts.on("-i S", String) do |s|
        filarr = s.split
        filarr.each {|f| options.include_files.insert(-1, f)}
      end

      opts.on("-D M", String) do |m|
        options.macros.insert(-1, m)
      end

      opts.on("--codefile S", String) do |s|
        options.codefile = File.expand_path(s)
      end

      opts.on("--directory S", String) do |s|
        options.directory = s
      end

      opts.on("--interface S", String) do |s|
        options.interface = s
      end

      opts.on("--package S", String) do |s|
        options.package = s
      end

      opts.on("--endian S", String) do |s|
        options.endian = s
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
# Performs a check of the user provided arguments
#
class ArgumentCheck

  def self.is_big_endian?
    [1].pack("s") == "\0\1"
  end

  def self.is_little_endian?
    !ArgumentCheck.is_big_endian?
  end

  def self.check
    SyntaxDescription.describe() if @@options.help == true

    # Check cpp
    unless @@options.cpp.empty?
      file = @@options.cpp.split[0]
      raise ArgumentError, "Cannot execute #{@@options.cpp}\n" unless File.executable?(file)
    else
      if Config::CONFIG["host_os"].downcase =~ /solaris/
        @@options.cpp = "/usr/lib/cpp" 
      elsif Config::CONFIG["host_os"].downcase =~ /linux/
        @@options.cpp = "/usr/bin/cpp" 
      else
        @@options.cpp = "/usr/lib/cpp" 
      end
    end

    raise ArgumentError, "Codefile doesn't exist" unless
      @@options.codefile.empty? || File.exist?(@@options.codefile)

    raise ArgumentError, "Directory doesn't exist" unless
      @@options.directory.empty? || File.exist?(@@options.directory)

    unless @@options.endian.empty?
      if @@options.endian !~ /big|little/
        raise ArgumentError, "Endian contains erroneous value"
      end
      @@endian = @@options.endian.eql?("big") ? "BIG_ENDIAN" : "LITTLE_ENDIAN"
    end

    @@options.include_paths.each {|i| puts "Warning: Non-existent include path #{i}\n" \
      unless File.exists?(i)}
  end

end

#
# Print options
#
class Printoptions

  def self.list
    puts "@@options.args=         #{@@options.args}"
    puts "@@options.cpp=          #{@@options.cpp}"
    print "@@options.include_paths= "; @@options.include_paths.each {|f| print f, " "};puts
    print "@@options.include_files= "; @@options.include_files.each {|f| print f, " "};puts
    print "@@options.macros= "; @@options.macros.each {|m| print m, " "};puts
    puts "@@options.codefile=     #{@@options.codefile}"
    puts "@@options.directory=    #{@@options.directory}"
    puts "@@options.interface=    #{@@options.interface}"
    puts "@@options.package=      #{@@options.package}"
    puts "@@options.endian=       #{@@options.endian}"
    puts "@@options.help=         #{@@options.help}"
    puts "@@options.verbose=      #{@@options.verbose}"
    puts "@@options.debug=        #{@@options.debug}"
    print "@@options.header_files= "; @@options.header_files.each {|f| print f, " "};puts
  end

end
