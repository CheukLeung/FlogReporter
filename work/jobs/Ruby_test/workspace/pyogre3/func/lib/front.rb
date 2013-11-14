require 'fileutils'
require "Crubyparse"
require "pp"

class Front

  #
  # Concatenate and read all C header files, extracting all lines containing '#define',
  # except macro definitions. 
  # 'ctable' will hold 2 types of elements: 
  # 1. Ordinary #defines that can be used during signal description generation.
  # 2. Tuples associating signal name with signal number and signal struct.  
  #
  # Additionally, the files are searched for directives (written as C constants)
  # describing handling of dynamic arrays and unions
  # 'atable' will hold 3 types of elements:.
  # 1. Tuples used to specify dynamic array handling, (full_path_to_array, variablename),
  #    where variablename will contain the correct array size.
  # 2. Tuples used to specify union handling, (full_path_to_union, variablename), where
  #    variablename will specify which variant(member) should be selected.
  # 3. A set of tuples specifying selector mapping, (full_path_to_union, selectorvalue, 
  #    member), where each selectorvalue is mapped to a specific member in the union.
  #
  # The header files are concatenated and preprocessed by cpp to generate an array
  # used in phase 2.
  #
  def self.process_header_files
    atable = {"ARRAY_SIZE"=>[], "UNION_SELECTOR"=>[], "SELECTOR_MAPPING"=>[]}
    ctable = {}
    itable = []
    augmented_file = "tmp.augmented_file"
    header_files = ""
    
    @@options.header_files.each {|hname| header_files << "#{hname} "}
    pipe = IO.popen("cat #{header_files}")
    
    File.open("#{augmented_file}", "w+") do |auger|
      pipe.readlines.each do |row|
        auger.puts row
        supp = true
        
        # Extract #include information ( #include "file" or #include <file> )
        if row =~ (/^\s*(\#\s*include\s+["<].+[">])/)
          itable.push $1
        end
        
        # match '#define A' but not '#define A(...)'
        if row =~ (/^\s*\# \s* define \s+ (\w+) [^\(]/x)
          constant_name = $1
          ctable[constant_name] = {"value" => nil} unless ctable.has_key?(constant_name)
          
          # Extract any supplemental information from end part of the #define
          if row =~ (/\/\* *!- *SIGNO\s*\(\s*struct\s*(\w+)\s*\) *-! *\*\/\s*$/)
            elem_type = 'struct'
          elsif row =~ (/\/\* *!- *SIGNO\s*\(\s*union\s*(\w+)\s*\) *-! *\*\/\s*$/)
            elem_type = 'union'
          elsif row =~ (/\/\* *!- *SIGNO\s*\(\s*enum\s*(\w+)\s*\) *-! *\*\/\s*$/)
            elem_type = 'enum'
          elsif row =~ (/\/\* *!- *SIGNO\s*\(\s*(\w+)\s*\) *-! *\*\/\s*$/)
            elem_type = 'type'
          else
            supp = false
          end
 
          if supp
            if ctable[constant_name].has_key?("#{elem_type}")
              ctable[constant_name]["#{elem_type}"].push($1)
            else
              ctable[constant_name]["#{elem_type}"] = [$1] 
            end
            auger.puts "struct dummy1_sigpa_#{elem_type}_#{$1} \{int dummy2_sigpa_#{elem_type}_#{constant_name};\};"
          end
        end
        # Extract information concerning dynamic array and union handling
        if row =~ (/\/\* *!- *ARRAY_SIZE\s*\(\s*([\w.]+)\s*,\s*(\w+)\s*\) *-! *\*\/\s*$/)
          atable["ARRAY_SIZE"] << [$1, $2]
        elsif row =~ (/\/\* *!- *UNION_SELECTOR\s*\(\s*([\w.]+)\s*,\s*(\w+)\s*\) *-! *\*\/\s*$/)
          atable["UNION_SELECTOR"] << [$1, $2]
        elsif row =~ (/\/\* *!- *SELECTOR_MAPPING\s*\(\s*([\w.]+)\s*,\s*(\w+)\s*,\s*(\w+)\s*\) *-! *\*\/\s*$/)
          atable["SELECTOR_MAPPING"] << [$1, $2, $3]
        end
      end
    end

    if @@options.debug
      File.delete("debug_files.zip") if File.exists?("debug_files.zip")
      @@options.header_files.each {|hname| system("zip -q -j debug_files #{hname}") }
      File.open("command_line_file", "w+") do |clf|
        args = (@@options.args.collect {|arg| arg + " "}).to_s
        clf.puts "\# #{$0} #{args}"
      end
      system("zip -q -j debug_files command_line_file")
      File.delete("command_line_file")
      if defined? @@options.codefile
        unless @@options.codefile.empty?
          system("zip -q -j debug_files #{@@options.codefile}")
        end
      end
    end

    # Create a file to be included when calling cpp
    tempfile = "tmp.#{$$}"
    special_line = "!!!---\"SIGNAL PARSER EXTRA DATA FOR CPP BEGINS HERE\"!!!---\n"
    
    File.open(tempfile, "w+") do |tmpf|
      (@@options.include_files).each do |includefile|
        tmpf.puts "#include \"#{includefile}\"\n"
      end

      File.open(augmented_file, "r") do |auger|
        auger.readlines.each {|r| tmpf.puts r}     
      end
      File.delete(augmented_file)

      tmpf.puts "\n\n", special_line
      ctable.each_key { |key| tmpf.puts "\"#{key}\"=#{key}\n" }
    end

    # Build the command line for invoking CPP
    # cpp -I <include dir> -I <include dir>... <header_files> <tmp.$$>:

   @@options.each {|opt| puts "#{opt}"}    

    cpp_command = " " + @@options.cpp +  (@@options.include_paths.collect {|x| " -I#{x}"}).to_s +
      (@@options.macros.collect {|x| " -D#{x}"}).to_s + " #{tempfile}"

#   cpp_command = " /usr/bin/cpp #{tempfile}"

    puts "Now running #{cpp_command}"

    # Collect the output from cpp up to special line
    cpp_output = []

    pipe = IO.popen("#{cpp_command}")
    while line = pipe.gets
      break if line.eql?(special_line)
      if line =~ (/struct dummy1_sigpa_(\w+?)_(\w+) \{int dummy2_sigpa_(\w+?)_(\w+);\};/)
        if ctable.has_key?($4) && ctable[$4].has_key?($1)
          if ctable[$4][$1].length > 1
            ctable[$4][$1].each do |elem|
              ctable[$4][$1].delete(elem) unless elem.eql?($2)
            end
          end  
        end      
      else
        cpp_output << line
      end
    end

    if @@options.debug
      rcf = File.open("rawcppfile", "w+")
      rcf.puts cpp_output
    end

    # Collect the output from cpp containing the extra data
    while line = pipe.gets
      rcf.puts line if @@options.debug
      if (line =~ /"(\w+)"=(.*)/) 
        if $1.eql?($2)         # Out-commented constant
          ctable.delete($1)
        elsif  ctable.has_key?("#{$1}")
          ctable[$1]["value"] = $2
        end
      else
        raise RegexpError, "Unexpected format in cpp output for extra data:\n#{line}"
      end
    end

    if @@options.debug
      rcf.close
      system("zip -q -j debug_files rawcppfile")    
      File.delete("rawcppfile")
    end
    
    # Filter the raw output from cpp: Remove leading blanks, new line, CPP position indication,
    # and possible other cpp things 
    cpp_str = cpp_output.to_s

    loop do
      next if cpp_str.sub!(/^[ \t\f\r]+/o, '')  # Suppress spaces
      next if cpp_str.sub!(/^[ \t\f\r]*\n[ \t\f\r]*/o, '')  # Next line
      next if cpp_str.sub!(/^#.*/, '')	      # Remove all lines starting with a '#'
      break
    end

    if @@options.debug
      File.open("trimmedcppfile", "w+") do |tcf|
        tcf.puts cpp_str
      end
      system("zip -q -j debug_files trimmedcppfile")
      File.delete("trimmedcppfile")
    end

    File.delete(tempfile)
    
    # Run through hash of constant values, deleting any suspect entries. Perform eval on expressions.

    ctable.each_key do |key|
      puts "Processing constant: #{key} = #{ctable[key]["value"]}\n" if @@options.verbose
      val = ctable[key]["value"].sub(/^\s+(.*?)\s+$/, '\1')
      
      if val == nil || val.eql?("")  ## Delete constants with no value (or empty string)
        warn "Constant: #{key} has no value (ignored)\n"
        ctable.delete(key)
      elsif val =~ /^\s*"(\\"|[^"])*"\s*$/  ## Value is a string
        # leave it unchanged
      elsif val =~ /^\s*'(\\'|[^'])*'\s*$/  ## Value is a character (accept more than 1)
        # leave it unchanged
      else  ## Value is probably an expression. If it can be eval'ed, substitute it with the computed value
        val.gsub!(/[uU][lL]|[lLuU]/, '')   ## Remove suffixes (suffix F is left for hex!)
        
        if val =~ /(\(\s*[A-Za-z_][^\)]*\))/  ## Remove casts
          match = $&
          if match !~ /\+/
            val.gsub!(match, '')
            warn "Constant: #{key} value: #{ctable[key]["value"]} dropping \"#{match}\" (cast?)"
          end
        end

        begin
        computed_val = eval val

        if defined?(computed_val) and computed_val.is_a?(Integer)
          ctable[key]["value"] = computed_val
        else
          warn "Ignored: Constant: #{key}: unusual value: #{ctable[key]["value"]} (missing include directories?)"
        end
        rescue
         puts "Cannot evaluate: #{val}"
        end
      end
    end

    # returns the association table and constant table (both for phase 3), and preprocessed_header_files
    # (for phase 2)
    return atable, ctable, cpp_str, itable
  end

  #
  # Parse the C header files. The parser in the module Crubyparse is called. It will 
  # return the results in the form of 5 tables: 
  # symbol_table, structtag_table, uniontag_table, enumtag_table, typedef_table.
  #
  def self.cparse(preprocessed_header_files)
    parser = Crubyparse.new
    
    begin
      tables = parser.parse(preprocessed_header_files, @@options)
      #pp tables[0]["table_data"]
      puts "Parsing OK"
    rescue ParseError
      puts $!
      exit
    end
    tables
  end
  
end
