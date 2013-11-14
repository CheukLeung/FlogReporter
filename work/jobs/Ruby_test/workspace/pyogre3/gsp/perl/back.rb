require 'tree'
require 'emit'
require 'pp'

#
# Type table
#
@@tt = 
{"U8" => {"signed" => "unsigned", "size" => 1, "align" => 1, "type" => "char"},
 "U16" => {"signed" => "unsigned", "size" => 2, "align" => 2, "type" => "short"},
 "U32" => {"signed" => "unsigned", "size" => 4, "align" => 4, "type" => "long"},
 "S8" =>  {"signed" => "signed", "size" => 1, "align" => 1, "type" => "char"},
 "S16" => {"signed" => "signed", "size" => 2, "align" => 2, "type" => "short"},
 "S32" => {"signed" => "signed", "size" => 4, "align" => 4, "type" => "long"},
 "SIGSELECT" => {"signed" => "unsigned", "size" => 4, "align" => 4, "type" => "long"},
 "OSBOOLEAN" => {"signed" => "unsigned", "size" => 1, "align" => 1, "type" => "char"},
 "enum" => {"signed" => "unsigned", "size" => 4, "align" => 4, "type" => "long"}
}

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

@@grove = {}  # Holds a collection of trees

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
        if signal[1][0] == struct[0] && struct[1].has_key?('.type') && struct[1].has_key?('.type_or_id_name')
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
  # Compute padding
  #
  def compute_padding(offset, alignment)
    misalign = offset % alignment
    if misalign > 0
      alignment - misalign
    else
      0
    end
  end

  #
  # Insert padding members in children array when necessary. 
  # Structs can get padding members between ordinary members, plus 
  # an extra padding at the end to make the struct size evenly 
  # dividable by its alignment.
  # Unions can only get the end padding. 
  #
  def insert_padding(node)
    ca = node.children.clone
    ind = -ca.length

    if node.kind.eql?("struct") || 
        (node.kind.eql?("array") && node.basetype.eql?("struct"))
      offset = ca[0].size
      if ca.length > 1
        ca[1..-1].each do |c|
          pad = compute_padding(offset, c.align)
          if pad > 0
            x = Tree.new("padding_#{@extcount}", "padding", node)
            x.size = pad
            x.level = node.level + 1
            x.leaf = true
            node.children.insert(ind, x)
            @extcount += 1
          end
          ind += 1
          offset += pad + c.size
        end
      end
    elsif node.kind.eql?("union") || 
        (node.kind.eql?("array") && node.basetype.eql?("union"))
      offset = (ca.collect {|c| c.size}).max
    end
    pad = compute_padding(offset, node.align)
    if pad > 0
      x = Tree.new("padding_#{@extcount}", "padding", node)
      x.size = pad
      x.level = node.level + 1
      x.leaf = true
      node.children.insert(-1, x)
      @extcount += 1
      offset += pad
      node.size = offset
    end
  end

  #
  # An endmark is inserted as a last member in each children array. Its
  # purpose is to make the job of indenting a trailing parenthesis correctly
  # during output file generation easier. 
  #
  def insert_endmark(node)
    x = Tree.new("endmark", "endmark", node)
    x.level = node.level + 1
    x.leaf = true
    node.children.insert(-1, x)
  end

  #
  # Decorate trees in grove, i.e. update nodes with pertinent information
  # and/or insert new leaf nodes:
  # Size and alignment is computed and filled in. 
  # For structs, unions, and non-leaf arrays, padding entries are inserted 
  # as necessary. (With non-leaf arrays we mean arrays whose elements are 
  # not leaves themselves).
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
          insert_padding(n)
          insert_endmark(n)
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
  # Check given paths against parse tree
  #
  def legal_path?(path, kind)
    patharr = path.split('.')
    @@grove.each do |k,v|
      curr = v["tree"]
      if curr.s_u_name.eql?(patharr[0])
        patharr.each_index do |index|
          next if index == 0
          name = patharr[index]
          if Tree.has_child?(curr, name)
            curr = Tree.get_child(curr, name)
          else
            return false unless index == patharr.length-1
          end
          return true if index == patharr.length-1 && curr.kind.eql?(kind)
        end
      end
    end
    false
  end

  #
  # Check paths given in directives for dynamic arrays and unions
  # 
  def check_paths(atable)
    atable.each do |k,v|
      if k.eql?("ARRAY_SIZE")
        v.each do |e|
          unless legal_path?(e[0], "array")
            puts "WARNING: The path \"#{e[0]}\" among the dynamic array directives is erroneous"
          end
        end
      else # UNION_SELECTOR, DENSE_UNION or SELECTOR_MAPPING
        v.each do |e|
          unless legal_path?(e[0], "union")
            puts "WARNING: The path \"#{e[0]}\" among the union directives is erroneous"
          end
        end
      end
    end
  end

  #
  # Generate signal description file.
  #
  def generate_signal_description(atable, ctable, tables)
    
    symbol_table, structtag_table, uniontag_table, enumtag_table, typedef_table = tables

    # Pick up the definition of SIGSELECT from the typedef table and change the type 
    # table entry if necessary.
    if typedef_table["quick_look"].has_key?("SIGSELECT")
      typedef_table["table_data"].each do |e|
        if e[0].eql?("SIGSELECT") && e[1][".type"] == "short"
          @@tt["SIGSELECT"]["size"] = 2
          @@tt["SIGSELECT"]["align"] = 2
          @@tt["SIGSELECT"]["type"] = "short"
        end
      end
    end

    # Add enum_consts from symbol_table to ctable
    symbol_table["table_data"].each do |e|
      if e[1].has_key?(".type") && e[1][".type"].eql?("enum_const") &&
         e[1].has_key?(".value")
        ctable[e[0]] = {"value"=>e[1][".value"]}
      end
    end

    # Go through all the constants collected during phase 1 and create five tables:
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

    signal_name_hash.each {|k,v| sorted_signo.push([k, v])}
    sorted_signo.sort! {|elem1, elem2| elem1[1][1] <=> elem2[1][1]}

    make_grove(structtag_table, typedef_table, signal_name_hash)
    decorate_grove()
    #@@grove.each {|a,b| Tree.level_print(b["tree"],40)}
    check_paths(atable)
    sd = SignalDescription.new(atable, @@options.package, sorted_constant_name, 
                               sorted_signals, sorted_signo,sorted_other_constant)
    sd.generate
  end

end
