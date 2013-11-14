require 'fileutils'
require "Crubyparse"
require 'set'

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
  # 'atable' will hold 4 types of elements:.
  # 1. Tuples used to specify dynamic array handling, (full_path_to_array, variablename),
  #    where variablename will contain the correct array size.
  # 2. Tuples used to specify union handling, (full_path_to_union, variablename), where
  #    variablename will specify which variant(member) should be selected.
  # 3. A set of tuples specifying selector mapping, (full_path_to_union, selectorvalue, 
  #    member), where each selectorvalue is mapped to a specific member in the union.
  # 4. Tuples used to specify dense unions, i.e. dynamic arrays containing unions where the 
  #    unions are not padded up to the max member size. Each tuple consists of 
  #    (full_path_to_union, selectorvalue, lengthvalue), where selectorvalue points out
  #    the union member, and lengthvalue tells the actual length of the dynamic array
  #    element. 
  # The header files are concatenated and preprocessed by cpp to generate an array
  # used in phase 2.
  #
  @@sigpa_5_tables = false

  def self.process_header_files
    @atable = {"ARRAY_SIZE"=>[], "UNION_SELECTOR"=>[], "SELECTOR_MAPPING"=>[], "DENSE_UNION"=>[]}
    @ctable = {}
    augmented_file = "tmp.augmented_file"
    header_files = ""
    
    @@options.header_files.each {|hname| header_files << "#{hname} "}
    pipe = IO.popen("cat #{header_files}")
    
    rowack = ""
    pat = Regexp.new(/\\s*$/)
    File.open("#{augmented_file}", "w+") do |auger|
      pipe.readlines.each do |row|
        if row =~ pat
          rowack += row.sub(pat,'').strip + ' '
          next
        end
        unless rowack.empty? 
          row = rowack + row 
          rowack = ""
        end
        auger.puts row
        supp = true
        # match '#define A' but not '#define A(...)'
        if row =~ (/^\s*\# \s* define \s+ (\w+) [^\(]/x)
          constant_name = $1
          @ctable[constant_name] = {"value" => nil} unless @ctable.has_key?(constant_name)
          
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
            if @ctable[constant_name].has_key?("#{elem_type}")
              @ctable[constant_name]["#{elem_type}"].push($1)
            else
              @ctable[constant_name]["#{elem_type}"] = [$1] 
            end
            auger.puts "struct dummy1_sigpa_#{elem_type}_#{$1} \{int dummy2_sigpa_#{elem_type}_#{constant_name};\};"
          end
        end
        # Extract information concerning dynamic array and union handling
        if row =~ (/\/\* *!- *ARRAY_SIZE\s*\(\s*([\w.]+)\s*,\s*(\w+)\s*\) *-! *\*\/\s*$/)
          @atable["ARRAY_SIZE"] << [$1, $2]
        elsif row =~ (/\/\* *!- *UNION_SELECTOR\s*\(\s*([\w.]+)\s*,\s*(\w+)\s*\) *-! *\*\/\s*$/)
          @atable["UNION_SELECTOR"] << [$1, $2]
        elsif row =~ (/\/\* *!- *SELECTOR_MAPPING\s*\(\s*([\w.]+)\s*,\s*(\w+)\s*,\s*(\w+)\s*\) *-! *\*\/\s*$/)
          @atable["SELECTOR_MAPPING"] << [$1, $2, $3]
        elsif row =~ (/\/\* *!- *DENSE_UNION\s*\(\s*([\w.]+)\s*,\s*(\w+)\s*,\s*(\w+)\s*\) *-! *\*\/\s*$/)
          @atable["DENSE_UNION"] << [$1, $2, $3]
        end
      end
    end

    if @@options.debug
      File.delete("debug_files.zip") if File.exists?("debug_files.zip")
      @@options.header_files.each {|hname| system("zip -q -j debug_files #{hname}") }
      File.open("command_line_file", "w+") do |clf|
        args = (@@options.args.collect {|arg| arg + " "}).join
        clf.puts "\# #{$0} #{args}"
      end
      system("zip -q -j debug_files command_line_file")
      File.delete("command_line_file")
      File.open("location_file", "w+") do |lof| 
        lof.puts "#{File.expand_path(`pwd`[0..-2])}"
      end
      system("zip -q -j debug_files location_file")
      File.delete("location_file")
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
      @ctable.each_key { |key| tmpf.puts "\"#{key}\"=#{key}\n" }
    end

    # Build the command line for invoking CPP
    # cpp -I <include dir> -I <include dir>... <header_files> <tmp.$$>:
    
    cpp_command = " " + @@options.cpp +  (@@options.include_paths.collect {|x| " -I#{x}"}).join +
      (@@options.macros.collect {|x| " -D#{x}"}).join + " #{tempfile}"

    puts "Now running #{cpp_command}" if @@options.verbose

    # Collect the output from cpp up to special line
    cpp_output = []

    pipe = IO.popen("#{cpp_command}")
    while line = pipe.gets
      break if line.eql?(special_line)
      if line =~ (/struct dummy1_sigpa_(\w+?)_(\w+) \{int dummy2_sigpa_(\w+?)_(\w+);\};/)
        if @ctable.has_key?($4) && @ctable[$4].has_key?($1)
          if @ctable[$4][$1].length > 1
            @ctable[$4][$1].each do |elem|
              @ctable[$4][$1].delete(elem) unless elem.eql?($2)
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
          @ctable.delete($1)
        elsif @ctable.has_key?("#{$1}")
          @ctable[$1]["value"] = $2
        end
      else
        raise RegexpError, "Unexpected format in cpp output for extra data:\n#{line}"
      end
    end

    if @@options.debug
      rcf.close
      system("zip -q -j debug_files rawcppfile")    
      File.delete("rawcppfile")

      headset = Set.new
      cpp_output.each do |rr|
        if rr =~ /^#\s+\d+\s+\"(.+)\"/
          t = $1
          headset.add(File.expand_path(t)) unless t =~ /^tmp\./
        end
      end
      headset.each do |incfile|
        system("zip -q debug_files #{incfile}")        
      end	
    end
    
    # Filter the raw output from cpp: Remove leading blanks, new line, CPP position indication,
    # and possible other cpp things 
    cpp_str = cpp_output.join

    loop do
      next if cpp_str.sub!(/^[ \t\f\r]+/o, '')  # Suppress spaces
      next if cpp_str.sub!(/^[ \t\f\r]*\n[ \t\f\r]*/o, '')  # Next line
      next if cpp_str.sub!(/^#.*/, '')	      # Remove all lines starting with a '#'
      break
    end

    File.open("trimmedcppfile", "w+") do |tcf|
      tcf.puts cpp_str
    end

    if @@options.debug
      system("zip -q -j debug_files trimmedcppfile")
    end

    File.delete(tempfile)
    
    # Run through hash of constant values, deleting any suspect entries. 
    # Perform eval on expressions to compute any arithmetic expressions.

    @ctable.each_key do |key|
      if key.eql?("SIGPA_5_TABLES")
        @@sigpa_5_tables = true
        next
      end

      puts "Processing constant: #{key} = #{@ctable[key]["value"]}\n" if @@options.verbose
      val = @ctable[key]["value"].sub(/^\s+(.*?)\s+$/, '\1')
      
      if val == nil || val.eql?("")  ## Delete constants with no value (or empty string)
        warn "Constant: #{key} has no value (ignored)\n"
        @ctable.delete(key)
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
            warn "Constant: #{key} value: #{@ctable[key]["value"]} dropping \"#{match}\" (cast?)"
          end
        end

        begin
          computed_val = eval val
          if defined?(computed_val) and computed_val.is_a?(Integer)
            @ctable[key]["value"] = computed_val
          end
        rescue
        end

      end
    end

    # returns the association table and constant table (both for phase 3), and preprocessed_header_files
    # (for phase 2)
    return @atable, @ctable, cpp_str
  end

  #
  # Returns true if '#define SIGPA_5_TABLES' is encountered in the input 
  #
  def self.sigpa_5_tables
    @@sigpa_5_tables
  end
  
  #
  # Sanity check. 
  # Checks if the signal struct pointed out in the #define linking signal name with signal number and 
  # signal struct actually refers to a known struct. Also checks if a signal number has been duplicated.
  #
  def self.sanity_test(tables)
    symbol_table, structtag_table, uniontag_table, enumtag_table, typedef_table = tables
    signotab = []

    @ctable.each do |a,b|
      if b.has_key?("struct")
        etab = "struct"
        name = b["struct"][0]
      elsif b.has_key?("type")
        etab = "type"
        name = b["type"][0]
      else
        etab = "none"
      end
      if etab =~ /struct|type/
        unless (etab.eql?("struct") && structtag_table["quick_look"].has_key?(name)) ||
          (etab.eql?("type") && typedef_table["quick_look"].has_key?(name))
          raise "The signal #{a} is not associated with any known struct. Check your signal file."
        end
      end
    end

    @ctable.each {|a,b| signotab << b["value"] if b.key?("struct")}
    signotab.sort!
    for i in 0...signotab.length
      if signotab[i] == signotab[i+1]
        raise "Signal number #{signotab[i]} duplicated. Check your signal file."
      end
    end
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
      File.delete("trimmedcppfile") if File.exist?("trimmedcppfile")
      Front.sanity_test(tables)
      puts "Parsing OK"
    rescue ParseError
      puts $!
      exit
    end
    tables
  end
  
end
