require 'tree'
require 'emit'
require 'set'

#
# Type table, holding size information for C types.
#
@@tt =
{"U8" => {"len" => 1, "jtype" => "int"},
 "U16" => {"len" => 2, "jtype" => "int"},
 "U32" => {"len" => 4, "jtype" => "long"},
 "S8" =>  {"len" => 1, "jtype" => "byte"},
 "S16" => {"len" => 2, "jtype" => "short"},
 "S32" => {"len" => 4, "jtype" => "int"},
 "SIGSELECT" => {"len" => 4, "jtype" => "long"},
 "OSBOOLEAN" => {"len" => 1, "jtype" => "boolean"},
 "enum" => {"len" => 4, "jtype" => "int"}}

#
# String extensions for anonymous structs and unions. Guarantees unique names.
#
@@anonext = 0

def get_anon_ext
  (@@anonext += 1).to_s
end

class Back

  def is_leaf?(elem)
    !elem[1].has_key?(".members")
  end

  def item_type(elem)
    elem[1][".type"]
  end

  def item_parse(elem)
    elem[1][".type_or_id_name"] =~ /\((.+)\): (\w+)/
    return $1.clone, $2.clone
  end

  def item_kind(elem)
    a,b = item_parse(elem)
    a
  end

  def item_name(elem)
    a,b = item_parse(elem)
    b
  end

  def is_struct_or_union?(elem)
    item_kind(elem) =~ %r{Struct|Union}
  end

  def is_type?(elem)
    item_kind(elem) =~ %r{Type}
  end

  def is_boolean?(elem)
    is_type?(elem) && item_name(elem).eql?("OSBOOLEAN")
  end

  def is_numeric?(elem)
    is_type?(elem) && @@tt.has_key?(item_name(elem)) && 
      !item_name(elem).eql?("OSBOOLEAN")
  end

  def is_anon?(elem)
    !elem[1].has_key?(".type_or_id_name")
  end

  #
  # Create a parse tree, i.e. a representation of a single nested data structure
  # in tree form.
  #
  def create_tree(node, elem, level, parent)
    node.level = level
    etype = item_type(elem)
    if etype =~ /array/
      node.kind = "array"
      node.arrsize = elem[1][".array_size"].to_i
      if elem[1].has_key?(".subtype") && elem[1][".subtype"].has_key?(".members")
        elem[1][".subtype"][".members"].each do |m|
          x = Tree.new(m[0], item_type(elem), node)
          node.create_child(x)
          create_tree(x, m, level+1, node)
        end
        if elem[1][".subtype"].has_key?(".type_or_id_name")
          elem[1][".subtype"][".type_or_id_name"] =~ /\((.+)\): (\w+)/
          node.s_u_name = $2.clone
        else
          node.s_u_name = "__ANON__"
        end
        node.data = elem[1][".subtype"][".type"] 
      else
        elem[1][".subtype"][".type_or_id_name"] =~ /\((.+)\): (\w+)/
        node.basetype = $2.clone
        node.leaf = true
      end
    elsif etype =~ /struct/
      node.kind = "struct"
      if is_anon?(elem)
        node.s_u_name = "__ANON__"
      else
        node.s_u_name = item_name(elem)
      end
      elem[1][".members"].each do |m|
        x = Tree.new(m[0], item_type(elem), node)
        node.create_child(x)
        create_tree(x, m, level+1, node)
      end
    elsif etype =~ /union/
      node.kind = "union"
      if is_anon?(elem)
        node.s_u_name = "__ANON__"
      else
        node.s_u_name = item_name(elem)
      end
      elem[1][".members"].each do |m|
        x = Tree.new(m[0], item_type(elem), node)
        node.create_child(x)
        create_tree(x, m, level+1, node)
      end
    elsif etype =~ /enum/
      node.kind = "enum"
      node.basetype = "enum"
      node.parent = parent
      node.leaf = true
    elsif is_numeric?(elem)
      node.kind = "numeric"
      node.basetype = item_name(elem)
      node.parent = parent
      node.leaf = true
    elsif is_boolean?(elem)
      node.kind = "boolean"
      node.basetype = item_name(elem)
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
  def make_grove(structtag_table, signal_name_hash)
    @@grove = {}
    
    structtag_table['table_data'].each do |elem|
      if signal_name_hash.has_key?(elem[0]) && elem[1].has_key?('.type') && 
          elem[1].has_key?('.type_or_id_name')
        name = elem[0]
        root = Tree.new(name, item_type(elem), nil)  
        @@grove[name] = root
        create_tree(root, elem, 0, root)
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
      Tree.postorder(b) do |n|
        if n.leaf
          if n.kind =~ /numeric|array|boolean|enum/
            n.size = @@tt[n.basetype]["len"]
          else
            raise "Unknown type in #{a}"
          end
        else
          n.size = (n.children.collect {|c| c.size}).max
        end
        if n.s_u_name =~ /__ANON__/
          if n.kind =~ /array/
            n.s_u_name = "Anonymous_#{n.data.up}_#{get_anon_ext}"
          else
            n.s_u_name = "Anonymous_#{n.kind.up}_#{get_anon_ext}"
          end
        end         
      end
      b.size = (b.children[1..-1].collect {|c| c.size}).max
    end
  end

  #
  # List grove
  #
  def list_grove()
    @@grove.each do |a,b|
      puts "\"#{a}\""
      Tree.preorder(b) do |n|
        #      puts "#{n.name}   #{get_path(n)}" unless n.parent.nil? 
        #      puts "#{n.name}" if n.leaf
      end
    end
  end

  #
  # Generate the signal classes
  #
  def generate_signal_classes(signal_name_hash, signal_num_hash, association_table)
    dirpath = @@options.directory.clone
    unless @@options.package.empty?
#      dirpath = "#{dirpath}/#{@@options.directory}"
      Dir.mkdir(dirpath) unless File.exist?(dirpath)
    end
    puts "creating signal files.....\n"
    filename_hrl = "#{dirpath}/#{@@options.package}.hrl"
    filename_erl = "#{dirpath}/#{@@options.package}.erl"   
    File.open(filename_erl, "w")# {|f| f.puts erl}
    File.open(filename_hrl, "w")# {|f| f.puts hrl}
    signal_class = SignalClass.new(@@grove, dirpath, @@options.package, 
                                     signal_name_hash, association_table, signal_num_hash)
    signal_class.generate
  end

  #
  # Generate Erlang files.
  #
  def generate_erlang_files(ctable, tables, association_table)
    
    symbol_table, structtag_table, uniontag_table, enumtag_table, typedef_table = tables

    # Go through all the constants collected during phase 1 and create four tables:
    #
    # sorted_constant_name:  all constants sorted in alphabetic order
    # sorted_signals:        signals in alphabetical order. Each signal consists of name, 
    #                        associated struct name, and signal number 
    # signal_name_hash       hash of signal names
    # sorted_other_constant: constants that are not signals (also alphabetical order)
    
    sorted_constant_name = ctable.keys.sort {|key1, key2| key1.downcase <=> key2.downcase}
    signal_num_hash = {}
    sorted_other_constant = []
    signal_name_hash = {}
    sorted_constant_name.each do |name|
      if ctable[name].has_key?("struct")
        signal_name_hash[ctable[name]["struct"][0]] = ctable[name]["value"]
        signal_num_hash[ctable[name]["value"]] = [ctable[name]["struct"][0],name]
      elsif ctable[name].has_key?("union") || ctable[name].has_key?("enum") ||
          ctable[name].has_key?("type")
        # not used
      else
        sorted_other_constant.push(name)
      end
    end
    
    make_grove(structtag_table, signal_name_hash)
    decorate_grove()
    generate_signal_classes(signal_name_hash, signal_num_hash, association_table)
  end

end
