$: << '/vobs/rbs/ogre/ruby/signal_parser_if'
require 'tree'
require 'emit'
require 'set'


# Maps simple numeric types used in parser to Ruby class names.
@@cct = {
  'signedchar' => 'CSignedChar',
  'unsignedchar' => 'CUnsignedChar',
  'signedshort' => 'CSignedShort',
  'unsignedshort' => 'CUnsignedShort',
  'signedint' => 'CSignedInt',
  'unsignedint' => 'CUnsignedInt',
  'signedlong' => 'CSignedLong',
  'unsignedlong' => 'CUnsignedLong',
  'signedlonglong' => 'CSignedLongLong',
  'unsignedlonglong' => 'CUnsignedLongLong',
  'enumconst' => 'CEnumConst',
  'pointer' => 'CPointer'
}

# Composite types
@@sut = ['CEnum', 'CArray', 'CStruct', 'CUnion']

# Holds a collection of trees
@@grove = {}  

#
# String extensions for anonymous structs and unions. Guarantees unique names.
#
@@anonext = 0

def get_anon_ext
  (@@anonext += 1).to_s
end

#
# Returns class name of a simple numeric type.
#
def numclass(valhash)
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
          else puts "Error: Not a numeric type"; exit
          end
  return "#{@@options.abi}::" + klass
end

#
# Deepcopy
#
class Object
  def deepcopy
    Marshal.load(Marshal.dump(self))
  end
end


class Back

  def sizeof(etype)
    require "lib/abi/#{@@options.abi.downcase}.rb"
    eval "#{@@options.abi}::#{etype}.size"
  end

  def initialize
    # Size info used to compute 'biggest'
    @@siz = {
      "U8" =>  sizeof("CUnsignedChar"),
      "U16" => sizeof("CUnsignedShort"),
      "U32" => sizeof("CUnsignedInt"),
      "S8" =>  sizeof("CSignedChar"),
      "S16" => sizeof("CSignedShort"),
      "S32" => sizeof("CSignedInt"),
      "#{@@options.abi}::CUnsignedChar" =>  sizeof("CUnsignedChar"),
      "#{@@options.abi}::CUnsignedShort" => sizeof("CUnsignedShort"),
      "#{@@options.abi}::CUnsignedInt" =>   sizeof("CUnsignedInt"),
      "#{@@options.abi}::CUnsignedLong" =>  sizeof("CUnsignedLong"),
      "#{@@options.abi}::CUnsignedLongLong" => sizeof("CUnsignedLongLong"),
      "#{@@options.abi}::CSignedChar" =>    sizeof("CSignedChar"),
      "#{@@options.abi}::CSignedShort" =>   sizeof("CSignedShort"),
      "#{@@options.abi}::CSignedInt" =>     sizeof("CSignedInt"),
      "#{@@options.abi}::CSignedLong" =>    sizeof("CSignedLong"),
      "#{@@options.abi}::CSignedLongLong" => sizeof("CSignedLongLong"),
      "#{@@options.abi}::CPointer" =>       sizeof("CPointer"),
      "OSBOOLEAN" => sizeof("CUnsignedInt"),
      "ENUM" =>      sizeof("CEnum"),
      "SIGSELECT" => sizeof("CUnsignedInt")
    }
  end
 
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

  def baseref_name(entry)
    entry[".base_ref_name"] =~ /\((.+)\): (\w+)/
    $2.clone
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
    is_type?(entry) && (item_name(entry) =~ /U8|U16|U32|S8|S16|S32|SIGSELECT/)
  end

  def is_native?(entry)
    entry[".type"] =~ /char|short|int|long/
  end

  def is_anon?(entry)
    !entry.has_key?(".type_or_id_name")
  end

  def check_type(entry)
    if item_type(entry) =~ /array|struct|union|enum|pointer/
      return $&
    elsif entry.has_key?(".type_or_id_name")
      name = item_name(entry)
      if name.eql?("OSBOOLEAN")
        return "boolean"
      elsif is_numeric?(entry)
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
      raise "Array \'#{node.name}\' has invalid size" if node.arrsize < 1
      if elem[1].has_key?(".subtype") && elem[1][".subtype"].has_key?(".members")
        elem[1][".subtype"][".members"].each do |m|
          x = Tree.new(m[0], item_type(elem[1]), node)
          node.create_child(x)
          create_tree(x, m, level+1, node)
        end
        if elem[1][".subtype"].has_key?(".type_or_id_name")
          node.s_u_name = item_name(elem[1][".subtype"])
        else
          node.s_u_name = "__ANON__"
        end
        node.basetype = node.data = elem[1][".subtype"][".type"].clone
      else
        subkind = check_type(elem[1][".subtype"])
        case subkind
        when "enum"
          node.basetype = "ENUM"
          node.data = item_name(elem[1][".subtype"])
        when "numeric_ose", "boolean"
          node.basetype = item_name(elem[1][".subtype"])
        when "native"
          node.basetype = numclass(elem[1][".subtype"])
        when "numeric_other"
          node.basetype = item_name(elem[1][".subtype"])
          node.data = item_type(elem[1][".subtype"])
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
      node.basetype = item_name(elem[1])
      node.parent = parent
      node.leaf = true
    when "pointer"
      node.kind = "pointer"
      node.basetype = item_type(elem[1][".subtype"])
      node.parent = parent
      node.leaf = true
    when "numeric_ose"
      node.kind = "numeric"
      node.basetype = item_name(elem[1])
      node.parent = parent
      node.leaf = true
    when "numeric_other"
      node.kind = "numeric"
      node.basetype = item_name(elem[1])
      node.data = item_type(elem[1])
      node.parent = parent
      node.leaf = true
    when "boolean"
      node.kind = "boolean"
      node.basetype = item_name(elem[1])
      node.parent = parent
      node.leaf = true
    when "native"
      node.kind = "numeric"
      node.basetype = numclass(elem[1])
      node.parent = parent
      node.leaf = true
    else
      raise "Node #{node.name} contains erroneous data" 
    end
  end

  #
  # Construct a grove of parse trees, representing signal structs found in
  # the structtag_table. Also insert typedef'ed signal structs.
  #
  def make_grove(structtag_table, typedef_table, signal_name_hash)    
    structtag_table['table_data'].each do |elem|
      if signal_name_hash.has_key?(elem[0]) && elem[1].has_key?('.type') && 
          elem[1].has_key?('.type_or_id_name')
        name = elem[0]
        root = Tree.new(name, item_type(elem[1]), nil)  
        @@grove[name] = {"signo" => signal_name_hash[elem[0]], "tree" => root}
        create_tree(root, elem, 0, root)
      end
    end
    typedef_table['table_data'].each do |elem|
      if signal_name_hash.has_key?(elem[0]) && (elem[1]['.type'] =~ /struct/)
        name = elem[0]
        root = Tree.new(name, item_type(elem[1]), nil)  
        @@grove[name] = {"signo" => signal_name_hash[elem[0]], "tree" => root}
        create_tree(root, elem, 0, root)
      elsif elem[1].has_key?('.type') && (elem[1]['.type'] =~ /struct|union/) &&
          elem[1].has_key?('.base_ref_name')
        br_name = baseref_name(elem[1])
        if signal_name_hash.has_key?(br_name)
          name = elem[0]
          root = @@grove[br_name]["tree"].deepcopy
          root.name = name
          @@grove[name] = {"signo" => signal_name_hash[br_name], "tree" => root}
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
  # Placeholders for anonymous structs and unions are replaced with unique names.
  #
  def decorate_grove()
    @@grove.each do |a,b|
       Tree.postorder(b["tree"]) do |n|
         if n.leaf
           if n.kind =~ /array/
             if n.basetype =~ /ENUM/
               n.size = @@siz["ENUM"]
             elsif @@siz.has_key?(n.basetype)
               n.size = @@siz[n.basetype]
             else
               n.size = @@siz[numclass({'.type' => n.data})]
             end
           elsif n.kind =~ /boolean/
             n.size = @@siz[n.basetype]
           elsif n.kind =~ /enum/
             n.size = @@siz["ENUM"]
           elsif n.kind =~ /pointer/
             n.size = @@siz["#{@@options.abi}::CPointer"]
           elsif n.kind =~ /numeric/
             if @@siz.has_key?(n.basetype)
               n.size = @@siz[n.basetype]
             else
               n.size = @@siz[numclass({'.type' => n.data})]
             end
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
       if b["tree"].children.length > 1
         b["tree"].size = (b["tree"].children[1..-1].collect {|c| c.size}).max
       else
         b["tree"].size = 4
       end
    end
  end

  #
  # List grove
  #
  def list_grove()
    @@grove.each do |a,b|
      puts "\n\"#{a}\""
      Tree.preorder(b["tree"]) do |n|
        p n.name; pp n.data
      end
    end
  end

  #
  # Generate Ruby class files.
  #
  def generate_signal_description(atable, ctable, tables)
    
    symbol_table, structtag_table, uniontag_table, enumtag_table, typedef_table = tables

    # Go through all the constants collected during phase 1 and create four tables:
    #
    # sorted_constant_name:  all constants sorted in alphabetic order
    # sorted_signals:        signals in alphabetical order. Each signal consists of name, 
    #                        associated struct name, and signal number 
    # signal_name_hash       hash of signal names
    # sorted_other_constant: constants that are not signals (also alphabetical order)
    
    sorted_constant_name = ctable.keys.sort {|key1, key2| key1.downcase <=> key2.downcase}
    sorted_signals = []
    sorted_other_constant = []
    signal_name_hash = {}
    sorted_constant_name.each do |name|
      if ctable[name].has_key?("struct")
        sorted_signals.push([name, ctable[name]["struct"][0], ctable[name]["value"]])
        signal_name_hash[ctable[name]["struct"][0]] = ctable[name]["value"]
      elsif ctable[name].has_key?("union") || ctable[name].has_key?("enum")
        # not used
      elsif ctable[name].has_key?("type")
        sorted_signals.push([name, ctable[name]["type"][0], ctable[name]["value"]])
        signal_name_hash[ctable[name]["type"][0]] = ctable[name]["value"]
      else
        sorted_other_constant.push([name, ctable[name]["value"]])
      end
    end
   make_grove(structtag_table, typedef_table, signal_name_hash)
   decorate_grove()
   #@@grove.each {|a,b| Tree.level_print(b["tree"],30)}
   sd = SignalDescription.new(atable, tables, @@options.outfile, sorted_constant_name,
                              sorted_signals, sorted_other_constant)
   sd.generate
  end

end
