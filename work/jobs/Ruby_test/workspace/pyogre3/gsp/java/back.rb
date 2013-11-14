require 'tree'
require 'emit'
require 'set'
require 'yaml_reader'
require 'pp'

#
# Type table, holding type information for C types, and corresponding Java types.
#
@@tt =
{"U8" => {"signed" => "unsigned", "size" => 1, "align" => 1, "jtype" => "int"},
 "U16" => {"signed" => "unsigned", "size" => 2, "align" => 2, "jtype" => "int"},
 "U32" => {"signed" => "unsigned", "size" => 4, "align" => 4, "jtype" => "long"},
 "S8" =>  {"signed" => "signed", "size" => 1, "align" => 1, "jtype" => "byte"},
 "S16" => {"signed" => "signed", "size" => 2, "align" => 2, "jtype" => "short"},
 "S32" => {"signed" => "signed", "size" => 4, "align" => 4, "jtype" => "int"},
 "SIGSELECT" => {"signed" => "unsigned", "size" => 4, "align" => 4, "jtype" => "long"},
 "OSBOOLEAN" => {"signed" => "unsigned", "size" => 1, "align" => 1, "jtype" => "boolean"},
 "enum" => {"signed" => "unsigned", "size" => 4, "align" => 4, "jtype" => "int"}}

#
# Native types
#
@@nn =
{"char" => {"size" => 1, "align" => 1},
 "short" => {"size" => 2, "align" => 2},
 "long" => {"size" => 4, "align" => 4},
 "longlong" => {"size" => 8, "align" => 8},
 "pointer" => {"size" => 4, "align" => 4},
 "int" => {"size" => 4, "align" => 4}
}

@@grove = {} #Holds a collection of trees

#
# String extensions for anonymous structs and unions. Guarantees unique names.
#
@@anonext = 0

def get_anon_ext
  (@@anonext += 1).to_s
end

class Back

  def is_leaf?(entry)
    !entry.has_key?(".members")
  end

  def item_type(entry)
    entry[".type"]
  end

  def item_parse(entry)
    entry[".type_or_id_name"] =~ /\((.+)\): (\w+)/
    return $1.clone, $2.clone
  end

  def item_kind(entry)
    if entry.has_key?(".type_or_id_name")
      a,b = item_parse(entry)
      return a
    end
    return false
  end

  def item_name(entry)
    a,b = item_parse(entry)
    b
  end

  def is_struct_or_union?(entry)
    item_kind(entry) =~ %r{Struct|Union}
  end

  def is_type?(entry)
    item_kind(entry) =~ %r{Type}
  end

  def is_boolean?(entry)
    is_type?(entry) && item_name(entry).eql?("OSBOOLEAN")
  end

  def is_numeric?(entry)
    is_type?(entry) && (item_name(entry) =~ /U\d+|S\d+|SIGSELECT/)
  end

  def is_native?(entry)
    entry[".type"] =~ /char|short|int|long/
  end

  def is_anon?(entry)
    !entry.has_key?(".type_or_id_name")
  end

  def check_type(entry)
    if item_type(entry) =~ /array|struct|union|enum/
      return $&
    elsif entry.has_key?(".type_or_id_name")
      name = item_name(entry)
      if name.eql?("OSBOOLEAN")
        return "boolean"
      elsif @@tt.has_key?(name)
        return "numeric_ose"
      else
        return "numeric_other"
      end
    else
      return "native"
    end
    "other"
  end

  #
  # Create a parse tree, i.e. a representation of a single nested data structure
  # in tree form.
  #
  def create_tree(node, elem, level, parent)
    node.level = level
    elemtype = check_type(elem[1])
    case elemtype
    when "array"
      node.kind = "array"
      node.arrsize = elem[1][".array_size"].to_i
      if elem[1].has_key?(".subtype") && elem[1][".subtype"].has_key?(".members")
        elem[1][".subtype"][".members"].each do |m|
          x = Tree.new(m[0], item_type(elem[1]), node)
          node.create_child(x)
          create_tree(x, m, level+1, node)
        end
        if elem[1][".subtype"].has_key?(".type_or_id_name")
          elem[1][".subtype"][".type_or_id_name"] =~ /\((.+)\): (\w+)/
          node.s_u_name = $2.clone
        else
          node.s_u_name = "__ANON__"
        end
        node.basetype = node.data = elem[1][".subtype"][".type"].clone
      else
        subkind = check_type(elem[1][".subtype"])
        case subkind
        when "enum"
          node.basetype = "enum"
          node.data = {".type" => elem[1][".subtype"][".type"]}
          node.data[".type_or_id_name"] = elem[1][".subtype"][".type_or_id_name"]
          arr = []
          elem[1][".subtype"][".values"].each { |k,v| arr << [k,v] }
          node.data[".values"] = arr.clone
          node.data[".values"].sort! { |a,b| a[1] <=> b[1] }
        when "numeric_ose", "boolean"
          elem[1][".subtype"][".type_or_id_name"] =~ /\((.+)\): (\w+)/
          node.basetype = $2.clone
        when "native", "numeric_other"
          node.basetype = "OTHER"
          node.data = {".type" => elem[1][".subtype"][".type"]}
          if elem[1][".subtype"].has_key?(".signed")
            node.data[".signed"] = elem[1][".subtype"][".signed"] 
          end
          if elem[1][".subtype"].has_key?(".type_or_id_name")
            node.data[".type_or_id_name"] = elem[1][".subtype"][".type_or_id_name"]
          end
        end
        node.leaf = true
      end
    when "struct", "union"
      node.kind = elemtype
      if is_anon?(elem[1])
        node.s_u_name = "__ANON__"
      else
        node.s_u_name = item_name(elem[1])
      end
      elem[1][".members"].each do |m|
        x = Tree.new(m[0], item_type(elem[1]), node)
        node.create_child(x)
        create_tree(x, m, level+1, node)
      end
    when "enum"
      node.kind = "enum"
      node.basetype = "enum"
      node.s_u_name = item_name(elem[1])
      node.parent = parent
      node.leaf = true
      arr = []
      elem[1][".values"].each { |k,v| arr << [k,v] }
      node.data = arr.clone
      node.data.sort! { |a,b| a[1] <=> b[1] }
    when "numeric_ose"
      node.kind = "numeric"
      node.basetype = item_name(elem[1])
      node.parent = parent
      node.leaf = true
    when "boolean"
      node.kind = "boolean"
      node.basetype = item_name(elem[1])
      node.parent = parent
      node.leaf = true
    when "native", "numeric_other"
      node.kind = "numeric"
      node.basetype = "OTHER"
      node.data = {'.type' => elem[1][".type"]}
      node.data[".signed"] = elem[1][".signed"] if elem[1].has_key?(".signed")
      if elem[1].has_key?(".type_or_id_name")
        node.data[".type_or_id_name"] = elem[1][".type_or_id_name"]
      end
      node.parent = parent
      node.leaf = true
    else
      raise "Node #{node.name} contains erroneous data" 
    end
  end

  #
  # Construct a grove of parse trees, representing signal structs found in
  # the structtag_table.
  #
  def make_grove(structtag_table, typedef_table, signal_name_hash)    
    signal_name_hash.each do |signal|
      structtag_table['table_data'].each do |struct|
        if signal[1][0] == struct[0] && struct[1].has_key?('.type') && 
           struct[1].has_key?('.type_or_id_name')
          name = signal[0]
          root = Tree.new(name, item_type(struct[1]), nil)
          @@grove[name] = {"signo" => signal[1][1], "tree" => root}
          create_tree(root, struct, 0, root)
        end
      end
      typedef_table['table_data'].each do |elem|
        if signal[1][0] == elem[0] && elem[1].has_key?('.type') && elem[1]['.type'] =~ /struct/
          name = signal[0]
          root = Tree.new(name, item_type(elem[1]), nil)
          @@grove[name] = {"signo" => signal[1][1], "tree" => root}
          create_tree(root, elem, 0, root)
        end
      end
    end
  end

  #
  # Decorate trees in grove, i.e. update nodes with pertinent information.
  # Since structs have to be aligned based on the alignment requirements of their
  # largest member, we update all such data structures recursively from bottom up,
  # allowing the max size to percolate upwards in the tree. The 'sigNo' member,
  # however, must be excluded from the calculation of 'size' for root, so the 
  # latter has to be recalculated. 
  #
  def decorate_grove()
    @@grove.each do |a,b|
      @extcount = 1
      Tree.postorder(b["tree"]) do |n|
        if n.leaf
          if n.basetype =~ /OTHER/
            n.align = @@nn[n.data['.type']]["align"]
          else
            n.align = @@tt[n.basetype]["align"]
          end
          if n.kind =~ /numeric|boolean|enum/
            if (n.kind =~ /numeric/) && (n.basetype =~ /OTHER/)
              n.size = @@nn[n.data['.type']]["size"]
            else
              n.size = @@tt[n.basetype]["size"]
            end
          elsif n.kind =~ /array/
            if n.basetype =~ /OTHER/
              n.size = @@nn[n.data['.type']]["size"] * n.arrsize
            else
              n.size = @@tt[n.basetype]["size"] * n.arrsize
            end
          end
        else # structs/unions/arrays
          n.align = (n.children.collect {|c| c.align}).max
          sizearr = n.children.collect {|c| c.size}
          case n.kind
          when "struct"
            n.size = sizearr.inject {|sum,e| sum+e}
          when "union"
            n.size = ((sizearr.max+n.align-1)/n.align)*n.align
          when "array"
            if n.basetype =~ /struct/
              n.size = (sizearr.inject {|sum,e| sum+e}) * n.arrsize
            elsif n.basetype =~ /union/
              n.size = sizearr.max * n.arrsize
            end
          end
        end
      end
    end
  end

  #
  # Generate the signal classes
  #
  def generate_signal_classes(signal_name_hash, yamltab)
    dirpath = @@options.directory.clone
    unless @@options.package.empty?
      dirpath = "#{dirpath}/#{@@options.package}"
      Dir.mkdir(dirpath) unless File.exist?(dirpath)
    end
    
    @@grove.each do |a,b|
      signal_class = SignalClass.new(b["tree"], dirpath, @@options.package, 
                                     signal_name_hash[a][1], a, yamltab)
      signal_class.generate
    end
  end

  #
  # Read codefile if given. Returns a Yaml_reader object.
  #
  def read_codefile
    y = YamlReader.new(@@options.codefile)
    yamltab = y.parse
  end

  #
  # Generate Java class files.
  #
  def generate_java_class_files(ctable, tables)
    
    symbol_table, structtag_table, uniontag_table, enumtag_table, typedef_table = tables

    # Go through all the constants collected during phase 1 and create four tables:
    #
    # sorted_constant_name:  all constants sorted in alphabetic order
    # sorted_signals:        signals in alphabetical order. Each signal consists of name, 
    #                        associated struct name, and signal number 
    # sorted_signo           signal numbers in sorted order
    # signal_name_hash       hash of signal names
    # sorted_other_constant: constants that are not signals (also alphabetical order)

    sorted_constant_name = ctable.keys.sort {|key1, key2| key1.downcase <=> key2.downcase}
    sorted_signals = []
    sorted_signo = []
    signal_name_hash = {}
    sorted_other_constant = []
    
    sorted_constant_name.each do |name|
      if ctable[name].has_key?("struct") 
        sorted_signals.push([name, ctable[name]["struct"][0], ctable[name]["value"]])
        signal_name_hash[name] = [ctable[name]["struct"][0], ctable[name]["value"]] 
      elsif ctable[name].has_key?("union") || ctable[name].has_key?("enum")
        # not used
      elsif ctable[name].has_key?("type")
        sorted_signals.push([name, ctable[name]["type"][0], ctable[name]["value"]])
        signal_name_hash[name] = [ctable[name]["type"][0], ctable[name]["value"]] 
      else
        sorted_other_constant.push([name, ctable[name]["value"]])
      end
    end

    make_grove(structtag_table, typedef_table, signal_name_hash)
    decorate_grove()
#    @@grove.each {|a,b| Tree.level_print(b["tree"],17)}
    yamltab = @@options.codefile.empty? ? nil : read_codefile
    generate_signal_classes(signal_name_hash, yamltab)
  end

end
