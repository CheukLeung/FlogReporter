require 'pp'
require 'set'

@@rd = "##{"-"*60}\n"
@@of = nil

#
# Returns string where first char has been converted to uppercase
#
class String
  def up
    self[0,1].upcase + self[1..-1]
  end
end

#
# Arrays and hashes used when printing signal description file. 
#
@@outarr = []   # array of elements, sorted in dependency order
@@outhash = {}  # hash with key = name, value = [printed, biggest]
@@deparr = []   # array of unsorted elements

#
# Non-application-specific OSE signals
#
OS_ATTACH_SIG = 252

#
# Generate the output file containing the signal description
#
class RubyClasses

  # Check for arrays of size 1 that haven't been described by any directive.
  # If the variable immediately preceding such an array is of the integer family,
  # it is interpreted as the size variable associated with the array. An entry
  # is added to the hash table.
  #
  def self.implicit_arrays(ahash)
    @@grove.each do |a,b|
      arr = []
      Tree.preorder(b["tree"]) {|n| arr << n}
      curr = nil
      arr.each do |n|
        path = RubyClasses.path_from_root(n)
        prev = curr
        curr = n
        if n.kind.eql?('array') && n.arrsize == 1 && 
          !ahash["ARRAY"].has_key?(path) && !prev.nil? &&
          (prev.parent == curr.parent) &&
          prev.kind.eql?('numeric') && (prev.basetype =~ /U\d+|S\d+/) &&
          !n.parent.kind.eql?('union') &&
          !(n.parent.children[0] == curr)
          ahash["ARRAY"][path] = prev.name
        end
      end
    end
  end

  # Rearrange the data from atable into a hash for easier handling. 
  # Also check for dynamic arrays that haven't been explicitly given through
  # directives. If any are found, a corresponding entry in the hash is added.
  #
  def self.make_hash(atable)
    ahash = {"UNION" => {}, "ARRAY" => {}}
    atable["ARRAY_SIZE"].each {|e| ahash["ARRAY"][e[0]] = e[1]}
    atable["UNION_SELECTOR"].each {|e| ahash["UNION"][e[0]] = {"sel"=>e[1]}}
    atable["DENSE_UNION"].each do |e|
      ahash["UNION"][e[0]] = {"sel"=>e[1], "denselen"=>e[2]}
    end
    atable["SELECTOR_MAPPING"].each do |e|
      ahash["UNION"][e[0]][e[1]] = e[2] if ahash["UNION"].has_key?(e[0])
    end
    implicit_arrays(ahash)
    ahash
  end

  def self.path_from_root(node)
    s = node.name.clone
    p = node.parent
    until p.nil?
      s.insert(0, "#{p.name}.")
      p = p.parent
    end
    s
  end

  def self.numclass(name, valhash)
    if valhash.has_key?('.signed')
      signed = (valhash['.signed'].eql?('signed')) ? true : false
    else
      signed = true
    end
    
    klass = case valhash['.type']
            when 'char'  then signed ? @@cct['signedchar'] : @@cct['unsignedchar']
            when 'short' then signed ? @@cct['signedshort'] : @@cct['unsignedshort']
            when 'int'   then signed ? @@cct['signedint'] : @@cct['unsignedint']
            when 'long'  then signed ? @@cct['signedlong'] : @@cct['unsignedlong']
            when 'longlong' then signed ? @@cct['signedlonglong'] : @@cct['unsignedlonglong']
            when 'pointer' then @@cct['pointer']
            else puts "Error: \'#{name}\' not a numeric type"; exit
            end
  end

  def self.array_has_dense_union(path, ahash)
    ahash["UNION"].each do |k,v|
      if v.has_key?("denselen") && k =~ /^#{path}/
        return "#{k.split(".")[1..-2].join(".")}.#{v["denselen"]}"
      end
    end
    nil
  end

  def self.directives(node, ahash)
    firstunion = true
    firstarray = true
    @g = ""
    @h = ""
    node.children.each do |c|
      path = RubyClasses.path_from_root(c)
      patharr = path.split('.')
      if c.kind =~ /union/
        if ahash["UNION"].has_key?(path)
          if firstunion
            @g << " self.union = [\n"
            firstunion = false
          end
          @g << "  {'sel' => \'#{ahash["UNION"][path]["sel"]}\', 'union' => \'#{patharr[-1]}\', "
          if ahash["UNION"][path].has_key?("denselen")
            @g << "'denselen' => \'#{ahash["UNION"][path]["denselen"]}\', "
          end
          maparr = []
          ahash["UNION"][path].each do |k,v|
            maparr << [k, v] unless (k.eql?("sel") || k.eql?("denselen"))
          end
          unless maparr.empty?
            maparr.sort! {|a,b| a[0]<=>b[0]}
            maparr.each {|e| @g << "\'#{e[0]}\' => \'#{e[1]}\', "}
          end
          @g.slice!(-2..-2) 	
          @g << "},\n"
        end
      elsif c.kind =~ /array/
        if ahash["ARRAY"].has_key?(path)
          if firstarray
            @h << " self.dynamic = [\n"
            firstarray = false
          end
          @h << "  {'size' => \'#{ahash["ARRAY"][path]}\', 'array' => \'#{patharr[-1]}\', 'path' => \'#{patharr[0..-2].join(".")}\'},\n"
          unless (d = RubyClasses.array_has_dense_union(path, ahash)).nil?
            @h.insert(-4, ", \'denselen\' => \'#{d}\'")
          end
        end
      end
    end
    unless firstunion
      @g.slice!(-2..-2)
      @g << " ]\n"
    end
    unless firstarray
      @h.slice!(-2..-2)
      @h << " ]\n"
    end
    @g + @h
  end

  def self.generate_struct_or_union(node, ahash)
    dep = []
    @t =""
    if node.kind =~ /struct/ || (node.kind =~ /array/ && node.data =~ /struct/)
      if node.level == 0 # top-level struct
        @t << "class #{node.name.up} < CStruct\n" 
      else # intermediate struct
        @t << "class #{node.s_u_name.up} < CStruct\n" 
      end
    else # union
      @t << "class #{node.s_u_name.up} < CUnion\n" 
    end
    @t << " self.members = [\n"
    node.children.each do |c|
      case c.kind
      when "numeric", "enum", "boolean"
        @t << "  [\'#{c.name}\', #{c.basetype.up}],\n"
        dep.push(c.basetype.up)
      when "pointer"
        @t << "  [\'#{c.name}\', #{@@options.abi}::CPointer],\n"
        dep.push("#{@@options.abi}::CPointer")
      when "struct", "union"
        @t << "  [\'#{c.name}\', #{c.s_u_name.up}],\n"
        dep.push(c.s_u_name.up)
      when "array"
        arrayname = RubyClasses.generate_array_intermediate(c)
        @t << "  [\'#{c.name}\', #{arrayname}],\n"
        dep.push(arrayname)
      end
    end
    @t.slice!(-2..-2)
    @t << " ]\n"
    @t << RubyClasses.directives(node,ahash)
    @t << " self.biggest = #{node.size}\n"
    @t << "end\n\n"
    name = node.level == 0 ? node.name.up : node.s_u_name.up
    @@deparr.push([name, dep, @t, node.kind])
  end

  def self.generate_array_intermediate(node)
    @r = ""
    if node.leaf
      if node.basetype =~ /ENUM/
        refname = node.data.up
      else
        refname = node.basetype.up
      end
    else
      refname = node.s_u_name.up
    end
    basename = refname.split(/::/)[-1]
    arrayname = "CArray#{node.arrsize}of#{basename}" 
    @r << "class #{arrayname} < CArray\n"
    @r << " self.type = #{refname}\n"
    @r << " self.size = #{node.arrsize}\n"
    @r << "end\n\n"
    dep = [refname]
    @@deparr.push([arrayname, dep, @r, "array"])
    arrayname
  end

  def self.generate_signal_struct(a, b, ahash)
    Tree.preorder(b["tree"]) do |node|
      case node.kind
      when "struct", "union"
        RubyClasses.generate_struct_or_union(node, ahash)
      when "array"
        if node.leaf
          RubyClasses.generate_array_intermediate(node)
        else
          RubyClasses.generate_struct_or_union(node, ahash)
        end
      end
    end
  end

  def self.generate_all_signal_structs(ahash)
    @@grove.each do |a,b|
      RubyClasses.generate_signal_struct(a,b,ahash)
    end
  end

  def self.generate_enum(elem)
    @p = ""
    dep = []
    @p << "class #{elem[0].up} < CEnum\n"
    @p << " self.members = [\n"
    sorted_arr = elem[1][".values"].sort {|a,b| a[1]<=>b[1]}
    sorted_arr.each do |e|
      @p << "  [\'#{e[0]}\', #{e[1]}],\n"
    end
    @p.slice!(-2..-2)
    @p << " ]\n"
    @p << "end\n\n"
    @@deparr.push([elem[0].up, dep, @p, "enum"])
  end

  def self.generate_all_enums(tables)
    tables[3]['table_data'].each do |elem|
      RubyClasses.generate_enum(elem)
    end
  end

  def self.generate_typedefs(tables)
    tables[4]['table_data'].each do |elem|
      @r = ""
      dep = []
      case elem[1]['.type']
      when "struct", "union", "function"
        # discard        
      when "enum"
        RubyClasses.generate_enum(elem)
      else # numeric types
        numeric_class = RubyClasses.numclass(elem[0], elem[1])
        @r << "class #{elem[0]} < #{numeric_class}; end\n\n"
        @@deparr.push([elem[0], dep, @r, "typedef"])
      end
    end
  end

  def self.eliminate_duplicates
    cash = {}
    carry = []
    @@deparr.each do |e|
      unless cash.has_key?(e[0])
        carry << e.clone
        cash[e[0]] = 1
      end
    end
    @@deparr = carry
  end
  
  def self.generate_basetypes
    for sign in ["CSigned", "CUnsigned"]
      for kind in ["Char", "Short", "Int", "LongLong", "Long"]
        @@deparr.push(["#{@@options.abi}::#{sign}#{kind}",  [], "", "basetype"])
      end
    end
    @@deparr.push(["#{@@options.abi}::CPointer",  [], "", "basetype"])
  end

  def self.missing_refs
    depset = Set.new
    outset = Set.new
    @@deparr.each {|e| e[1].each {|g| depset.add(g)}}
    @@outarr.each {|f| f[0].each {|h| outset.add(h)}}
    (depset-outset).each {|k| puts "Error: Declaration missing for '#{k}'"}
    raise "Missing declaration(s)"
  end

  def self.sort_output_in_dependency_order
    prevlen = @@deparr.length
    while !@@deparr.empty? 
      @@deparr.each do |elem|
        ok = true
        unless elem[1].empty?
          elem[1].each do |ref|
            if !@@outhash.has_key?(ref) 
              ok = false 
            end
          end
        end
        if ok
          @@outarr.push(elem.clone)
          @@outhash[elem[0].clone] = [false, 0]
        end 
      end
      @@deparr.delete_if {|e| @@outhash.has_key?(e[0])}
      currlen = @@deparr.length
      RubyClasses.missing_refs if currlen == prevlen
      prevlen = currlen
    end
  end

  def self.generate_non_specific_signal_structs
    @v = ""
    structname = "OsAttachS"
    @v << "class #{structname} < CStruct\n"
    @v << " self.members = [\n"
    @v << "  ['sigNo', SIGSELECT]\n"
    @v << " ]\n"
    @v << " self.biggest = 4\n"
    @v << "end\n\n"
    @@deparr.push([structname, ["SIGSELECT"], @v, 'struct'])
  end

  def self.write_output(sorted_signals)
    @signals = {}
    sorted_signals.each {|e| @signals[e[1].up] = 1}
    @@outarr.each do |elem|
      @@of.puts elem[2] unless @signals.has_key?(elem[0]) || elem[2].empty?
    end
    @@outarr.each do |elem|
      @@of.puts elem[2] if @signals.has_key?(elem[0])
    end
  end

  def self.list_arr(arr)
    arr.each do |e|
      s = "["
      e[1].each {|a| s << "\"#{a}\" "}  
      s << "]"
     puts "#{e[0]}  #{s}"
    end
    puts;puts
  end

  def self.generate(atable, tables, sorted_signals)
    ahash = RubyClasses.make_hash(atable)
    RubyClasses.generate_all_signal_structs(ahash)
    RubyClasses.generate_all_enums(tables)
    RubyClasses.generate_typedefs(tables)
    RubyClasses.generate_non_specific_signal_structs
    RubyClasses.generate_basetypes
    RubyClasses.eliminate_duplicates
    RubyClasses.sort_output_in_dependency_order
    RubyClasses.write_output(sorted_signals)
  end

end

#
# Generate the output file containing the signal description
#
class SignalDescription

  def initialize(atable, tables, outfile, sorted_constant_name, sorted_signals,
                 sorted_other_constant)
    @atable = atable
    @tables = tables
    @dirname = File.dirname(outfile)
    @basename = File.basename(outfile)
    @sorted_constant_name = sorted_constant_name
    @sorted_signals = sorted_signals
    @sorted_other_constant = sorted_other_constant
    @s = ""
  end

  def add_header
    @s = ""
    @hf = ""
    @@options.header_files.each {|name| @hf << "#    #{name}\n"}
    args = (@@options.args.collect {|arg| arg + " "}).join

    @s +=<<HEADER
################################################################################
################################################################################
#                                                                              #
#                            SIGNAL DESCRIPTION                                #
#                                                                              #
################################################################################
################################################################################
#
# WARNING: DO NOT MODIFY THIS FILE!!
# This file was automaticaly generated. Any modification will be lost the next
# time the generation occurs!
#
################################################################################
# This file was generated using #{$0}
# at #{Time.new}
# The following files were parsed:
#{@hf}#
# The signal parser was called from the following directory (pwd).
#    #{`pwd`[0..-2]}
#
# The following signal parser command line was used:
# ruby #{$0} #{args}
#
# Used Ruby #{RUBY_VERSION}
################################################################################

HEADER
    @@of.puts @s
  end

  def generate_signame_signo
    @t = ""
    @sorted_signals.each do |elem|
      @t << "#{elem[0]} = SIGSELECT.new_init(#{elem[2]})\n"
    end
    @t << "OS_ATTACH_SIG = SIGSELECT.new_init(#{OS_ATTACH_SIG})\n\n"
    @@of.puts @t
  end

  def generate_struct_factory
    @u = ""
    @u << "StructFactory = OGRE::StructFactory.instance\n"
    @sorted_signals.each do |elem|
      @u << "StructFactory.register(#{elem[0]}, #{elem[1].up}, \"#{elem[0]}\")\n"
    end
    @u << "StructFactory.register(OS_ATTACH_SIG, OsAttachS, \"OS_ATTACH_SIG\")\n\n"
    @@of.puts @u
  end

  def generate_other_constants
    @r = ""
    @sorted_other_constant.each {|e| @r << "#{e[0]}=#{e[1]}\n"}
    @r << "\n"
    @@of.puts @r
  end

  def add_main_module
    @s = ""
    @@options.module.each {|m| @s << "module #{m}\n"}
    @s << "require 'lib/abi/#{@@options.abi.downcase}'\n"
    @s << "require 'lib/base_types/ctype'\n"
    @s << "require 'signal'\n"
    @s << "include #{@@options.abi}\n\n"
    @@of.puts @s
    RubyClasses.generate(@atable, @tables, @sorted_signals)
    generate_signame_signo
    generate_struct_factory
    generate_other_constants
    @s = ""
    @@options.module.each {|m| @s << "end\n"}
    @@of.puts @s
  end

  def generate
    FileUtils.mkdir_p(@dirname) unless File.directory?(@dirname)
    ofname = "#{@dirname}/#{@basename}"

    @@of = File.open(ofname, "w")
    begin
      add_header
      add_main_module
      @@of.close
    rescue
      @@of.close
      File.delete(ofname)
      raise
    end
  end

end
