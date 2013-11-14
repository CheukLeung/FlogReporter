$: << File.dirname(__FILE__)
$: << File.join(File.dirname(__FILE__), "..", "lib")
# back.rb - Signal parser backend for Python

require 'tree'
require 'emit'
require 'set'

# Entended by jf2508
# See readme back.rb.txt for more info

# Maps simple numeric types used in parser to basetypes.
@@basetypes = {
  'signedchar'       => 'S8',
  'unsignedchar'     => 'U8',
  'signedshort'      => 'S16',
  'unsignedshort'    => 'U16',
  'signedint'        => 'S32',
  'unsignedint'      => 'U32',
  'signedlong'       => 'S32',
  'unsignedlong'     => 'U32',
  'signedpointer'    => 'U32',
  'signedlonglong'   => 'S64',
  'unsignedlonglong' => 'U64',
}

# Size info used to compute 'biggest'
@@siz = {
  'U8' => 1,
  'U16' => 2,
  'U32' => 4,
  'U64' => 8,
  'S8' => 1,
  'S16' => 2,
  'S32' => 4,
  'S64' => 8,
  'OSBOOLEAN' => 4,
  'ENUM' => 4,
  'SIGSELECT' => 4
}

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
# Deepcopy
#
class Object
  def deepcopy
    Marshal.load(Marshal.dump(self))
  end
end


class Back

  def item_type(elem)
    elem[1][".type"]
  end

  def item_name(elem)
    if not elem[1].has_key?(".type_or_id_name")
      return "__ANON__"
    end
    elem[1][".type_or_id_name"] =~ /\((.+)\): (\w+)/
    return $2.clone
  end

  def item_basetype(elem)
    sign = "signed"
    if elem[1].has_key?(".signed")
      sign = elem[1][".signed"]
    end
    type = elem[1][".type"]
    return @@basetypes[sign + type]
  end

  def baseref_name(elem)
    elem[1][".base_ref_name"] =~ /\((.+)\): (\w+)/
    $2.clone
  end

  def is_numeric?(elem)
    elem[1][".type"] =~ /char|short|int|longlong|long/
  end


  #
  # Create a parse tree, i.e. a representation of a single nested data structure
  # in tree form.
  #
  def create_tree(node, elem, level, parent)
    node.level = level
    node.data = Set.new([])
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
        sign = "signed"
        if elem[1][".subtype"].has_key?(".signed")
          sign = elem[1][".subtype"][".signed"]
        end
        type = elem[1][".subtype"][".type"]
        if type == "enum" 
          node.basetype = 'S32'
        else
          node.basetype = @@basetypes[sign + type]
        end
        node.leaf = true
      end
    elsif etype =~ /struct|union/
      node.kind = $&
      node.s_u_name = item_name(elem)
      elem[1][".members"].each do |m|
        if m[1][".type"].eql?("error")  
         # Ignore illegal line from signal struct, extended by jf2508
         puts "#{m[0]}, .type = #{m[1][".type"]}, ignored"
        else 
         x = Tree.new(m[0], item_type(elem), node)
         node.create_child(x)
         create_tree(x, m, level+1, node)
        end
      end
    elsif etype =~ /enum/
      node.kind = "enum"
      node.basetype = "S32"
      node.parent = parent
      node.leaf = true
    elsif is_numeric?(elem)
      node.kind = "numeric"
      node.basetype = item_basetype(elem)
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
           root = Tree.new(name, item_type(struct), nil)
           @@grove[name] = {"signo" => signal[1][1], "tree" => root}
           create_tree(root, struct, 0, root)
        end
      end
      typedef_table['table_data'].each do |elem|
        if signal[1][0] == elem[0] && elem[1].has_key?('.type') && elem[1]['.type'] =~ /struct/
          name = signal[0]
          root = Tree.new(name, item_type(elem), nil)
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
    offset = 0
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
      @extcount = 1
      Tree.postorder(b["tree"]) do |n|
        if n.leaf
          if n.kind =~ /numeric|boolean|enum/
            n.align = @@siz[n.basetype]
            n.size  = @@siz[n.basetype]
          elsif n.kind =~ /array/
            n.align = @@siz[n.basetype]
            n.size  = @@siz[n.basetype] * n.arrsize
          else
            raise "Unknown type in #{a}"
          end
        else
          n.align = (n.children.collect {|c| c.align}).max
          insert_padding(n)

          sizearr = n.children.collect {|c| c.size}
          case n.kind
          when "struct"
            n.size = sizearr.inject {|sum,e| sum+e}
          when "union"
            n.size = sizearr.max
          when "array"
            if n.basetype =~ /struct/
              n.size = (sizearr.inject {|sum,e| sum+e}) * n.arrsize
            elsif n.basetype =~ /union/
              n.size = sizearr.max * n.arrsize
            end
          end

        end
        if n.s_u_name =~ /__ANON__/
          if n.kind =~ /array/
            n.s_u_name = "Anonymous_#{n.data.up}_#{get_anon_ext}"
          else
            n.s_u_name = "Anonymous_#{n.kind.up}_#{get_anon_ext}"
          end
        end         
      end
      b["tree"].align = (b["tree"].children[1..-1].collect {|c| c.align}).max
    end
  end

  #
  # List grove
  #
  def list_grove()
    @@grove.each do |a,b|
      puts "\n\"#{a}\""
      Tree.preorder(b["tree"]) do |n|
        p n.name
      end
    end
  end

  #
  # Generate the signal classes
  #
  def generate_signal_classes(atable, 
                              tables, 
                              outfile, 
                              sorted_constant_name,
                              sorted_signals, 
                              sorted_other_constant)

    parts = outfile.split('/')
    if parts.length == 1
      directory, signal_definition_file = ".", parts[0]
    else
      directory, signal_definition_file = parts[0..parts.length-2].join("/"), parts[-1]
    end

    # Create director(ies) as needed
    FileUtils.mkdir_p(directory) unless File.directory?(directory)


    ofname = "#{directory}/#{signal_definition_file}"
    f = File.open(ofname, "w")
    begin
      f.puts "# #{signal_definition_file} - Signal description\n"
      f.puts "# ----------------------------------------------------------------\n"
      f.puts "# WARNING: Do not modify this file. It is automatically generated\n"
      f.puts "#          from signal files. Any modification will be lost the\n"
      f.puts "#          next time the file is generated.\n"
      f.puts "\n"
      f.puts "\"\"\"\n"
      f.puts "Signal description file generated from:\n"
      @@options.header_files.each {|name| f.puts "    #{name}\n"}
      f.puts "Generated by:\n"
      f.puts "    #{$0}\n"
      f.puts "\"\"\"\n\n"
      f.puts "import ogre\n\n"

      # Generate other constants
      sorted_other_constant.each do |a|
        f.puts "#{a[0]} = #{a[1]}"
      end

      # Generate enum constants
      tables[3]['table_data'].each do |e|
        f.puts "class #{e[0]}:"
        sorted_arr = e[1][".values"].sort {|a,b| a[1]<=>b[1]}
        sorted_arr.each do |v|
          f.puts "    #{v[0]} = #{v[1]}"
        end
      end

      # Generate classes
      @@grove.each do |a,b|
        signal_class = SignalClass.new(b['tree'], f, b['signo'], a)
        ahash = SignalClass.make_hash(atable)
        signal_class.generate(ahash)
      end

      # Generate signal registration
      f.puts "\n# ----\n"
      @@grove.each do |a,b|
        f.puts "ogre.Signal.register(#{a}.SIGNO, #{a})\n"
      end

      f.puts "\n# End of file\n"
      f.close
    rescue
      f.close
      File.delete(ofname)
      raise
    end

  end

  #
  # Generate Python class files.
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
        signal_name_hash[name] = [ctable[name]["struct"][0] , ctable[name]["value"]]
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

    generate_signal_classes(atable, 
                            tables, 
                            @@options.outfile, 
                            sorted_constant_name,
                            sorted_signals, 
                            sorted_other_constant)
  end

end
