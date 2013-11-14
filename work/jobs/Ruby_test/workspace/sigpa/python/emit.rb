require 'singleton'

#
# Returns string where first char has been converted to uppercase
#
class String
  def up
    self[0,1].upcase + self[1..-1]
  end
end

#
# This class keeps track of which regular structs have been generated, so 
# duplication can be avoided.
#
class Regtally

  include Singleton

  def initialize
    @regtally = {}
  end

  def add(node)
    @regtally[node.s_u_name] = 1
  end

  def has?(node)
    @regtally.has_key?(node.s_u_name)
  end

end

#
# Signal class. Traverses the signal tree in preorder, assembling the Python
# class description in the process.
#
class SignalClass

  attr_reader :signo, :name

  def initialize(root, file, signo, name)
    @root = root
    @file = file
    @signo = signo
    @name = name
    @recstr = ""
    @sendstr = ""
    @ind = 0
    @s = ""
    @regtally = Regtally.instance
    @first_child = 0
  end

  #
  #
  #
  def self.make_hash(atable)
    ahash = {"UNION" => {}, "ARRAY_ARR" => {}, "ARRAY_SIZ" => {}}

    atable["ARRAY_SIZE"].each {|e| 
      container = e[0].split('.')[0..-2].join('.')
      array = e[0].split('.')[-1]
      arr = container + '.' + array
      siz = container + '.' + e[1]
      ahash["ARRAY_ARR"][siz] = array
      ahash["ARRAY_SIZ"][arr] = e[1]
    }

    atable["UNION_SELECTOR"].each {|e| 
      ahash["UNION"][e[0]] = {"sel" =>e[1]}
    }

    atable["SELECTOR_MAPPING"].each do |e|
      ahash["UNION"][e[0]][e[2]] = e[1] if ahash["UNION"].has_key?(e[0])
    end

    ahash
  end

  #
  #
  #
  def self.path_from_root(node)
    s = node.name.clone
    p = node.parent
    until p.nil?
      if(p.kind.eql?("struct") && p.level == 0)
        s.insert(0, "#{p.s_u_name}.")
        p = p.parent
      else
        s.insert(0, "#{p.name}.")
        p = p.parent
      end
    end
    s
  end

  def ind(offset = 0)
    return "    "*(@ind + offset)
  end

  def generate_attr_list(ahash)
    @s << "\n#{ind(1)}ATTR_LIST = [\n"
    if @signo != 0
        @s << "#{ind(2)}'sig_no',\n" 
    end
    @root.children[@first_child..-1].each do |node| 
      next if node.kind == "padding"
      path = SignalClass.path_from_root(node)
      if not ahash["ARRAY_ARR"].has_key?(path)
        @s << "#{ind(2)}'#{node.name}',\n" 
      end
    end
    @s << "#{ind(1)}]\n"
  end

  def generate_signal_class
    @s << "#{ind}\n"
    @s << "#{ind}# ----\n"
    if @signo != 0
      @s << "#{ind}class #{@name}(ogre.Signal):\n"
      @s << "#{ind(1)}\"\"\"Signal description for signal #{@name}\"\"\"\n"
      if @root.children[0].kind.eql?("numeric") && 
          @root.children[0].name.eql?("sig_no")
        @s << "\n#{ind(1)}SIGNO = #{@signo}\n"
        @first_child = 1
      end
    else
      @s << "#{ind}class #{@root.s_u_name}(ogre.Struct):\n"
      @s << "#{ind(1)}\"\"\"Signal description for #{@root.kind} #{@root.s_u_name}\"\"\"\n"
    end
  end

  def generate_constructor(ahash)
    @s << "#{ind(1)}\n"
    @s << "#{ind(1)}def __init__(self):\n"
    if @first_child != 0
      @s << "#{ind(2)}ogre.Signal.__init__(self, self.SIGNO)\n"
    else
      @s << "#{ind(2)}ogre.Struct.__init__(self)\n"
    end

    @root.children[@first_child..-1].each do |c|
      path = SignalClass.path_from_root(c)
      case c.kind
      when "numeric"
        if ahash["ARRAY_ARR"].has_key?(path)
          @s << "#{ind(2)}# self.#{c.name} = 0\n"
        else
          @s << "#{ind(2)}self.#{c.name} = 0\n"
        end
      when "boolean"
        @s << "#{ind(2)}self.#{c.name} = False\n"
      when "enum"
        @s << "#{ind(2)}self.#{c.name} = 0\n"
      when "struct", "union"
        @s << "#{ind(2)}self.#{c.name} = #{c.s_u_name}()\n"
      when "array"
        if c.leaf
          @s << "#{ind(2)}self.#{c.name} = ogre.Array([ 0 for i in range(#{c.arrsize}) ])\n"
        elsif !c.s_u_name.empty?
          @s << "#{ind(2)}self.#{c.name} = ogre.Array([ #{c.s_u_name}() for i in range(#{c.arrsize}) ])\n"
        end
      end
    end

  end

  def generate_unserialize_prelude
    @recstr << "\n#{ind(1)}def unserialize(self, reader, tag=None):\n"
  end

  def generate_serialize_prelude
    @sendstr << "\n#{ind(1)}def serialize(self, writer, tag=None):\n"
  end
 
  # --- generate classes

  def visit_numeric(ahash, node)
    path = SignalClass.path_from_root(node)
    if ahash["ARRAY_ARR"].has_key?(path)
      dyn_arr = ahash["ARRAY_ARR"][path]
      @recstr << "#{ind(2)}_#{node.name} = reader.read#{node.basetype}()\n"
      @sendstr << "#{ind(2)}writer.write#{node.basetype}(len(self.#{dyn_arr}))\n"
    else
      @recstr << "#{ind(2)}self.#{node.name} = reader.read#{node.basetype}()\n"
      @sendstr << "#{ind(2)}writer.write#{node.basetype}(self.#{node.name})\n"
    end
  end

  def visit_enum(ahash, node)
    @recstr << "#{ind(2)}self.#{node.name} = reader.readS32()\n"
    @sendstr << "#{ind(2)}writer.writeS32(self.#{node.name})\n"
  end

  def visit_array(ahash, node)
    path = SignalClass.path_from_root(node)
    arrsize = node.arrsize
    if ahash["ARRAY_SIZ"].has_key?(path)
      dyn_size = ahash["ARRAY_SIZ"][path]
      arrsize = '_' + dyn_size 
    end
    if node.leaf
      @recstr << "#{ind(2)}self.#{node.name} = reader.int_array(#{arrsize}, #{node.arrsize}, reader.read#{node.basetype})\n"
      @sendstr << "#{ind(2)}writer.int_array(self.#{node.name}, #{node.arrsize}, writer.write#{node.basetype})\n"
    else
      unless @regtally.has?(node)
        regstruct = SignalClass.new(node, @file, 0, "")
        regstruct.generate(ahash)
        @regtally.add(node)
      end
      @recstr << "#{ind(2)}self.#{node.name} = reader.composite_array(#{node.s_u_name}, #{arrsize}, #{node.arrsize}, reader.struct)\n"
      @sendstr << "#{ind(2)}writer.composite_array(#{node.s_u_name}, self.#{node.name}, #{node.arrsize}, writer.struct)\n"
    end
  end

  def visit_struct(ahash, node)
    path = SignalClass.path_from_root(node)
    unless @regtally.has?(node)
      regstruct = SignalClass.new(node, @file, 0, "")
      regstruct.generate(ahash)
      @regtally.add(node)
    end

    if ahash["UNION"].has_key?(path)
      sel = ahash["UNION"][path]['sel']
      @recstr << "#{ind(2)}self.#{node.name}.unserialize(reader, self.#{sel})\n"
      @sendstr << "#{ind(2)}self.#{node.name}.serialize(writer, self.#{sel})\n"
    else
      @recstr << "#{ind(2)}self.#{node.name}.unserialize(reader)\n"
      @sendstr << "#{ind(2)}self.#{node.name}.serialize(writer)\n"
    end
  end

  #
  # Guess the size variable for one elements arrays.
  #
  def guess_dyn_array(ahash)
    prev_node = nil
    @root.children[@first_child..-1].each do |node|
      next if node.kind == "padding"

      if node.kind == "array" and node.arrsize == 1
        arr_path = SignalClass.path_from_root(node)
        if not prev_node.nil? and prev_node.kind == "numeric"
          siz_path = SignalClass.path_from_root(prev_node)
          if not ahash["ARRAY_SIZ"].has_key?(arr_path)
            ahash["ARRAY_SIZ"][arr_path] = prev_node.name
            ahash["ARRAY_ARR"][siz_path] = node.name
          end
        end

        if not ahash["ARRAY_SIZ"].has_key?(arr_path)
          puts "Can't guess the size variable for the dynamic array '#{node.name}'. Please,"
	  puts "specify the size variable with the following comment in the sig file:"
	  puts "/* !-ARRAY_SIZE(#{arr_path}, <size_variable>)-! */"
        end
      end

      prev_node = node
    end
  end

  # ---
  def visit_nodes(ahash)
    if_ = "if"
    i = 0
    unless @root.children.length == 1
      @recstr  << "#{ind(2)}reader.align(#{@root.align})\n"
      @sendstr << "#{ind(2)}writer.align(#{@root.align})\n"
    end

    @root.children[@first_child..-1].each do |node|
      #puts "CHILD: #{node}, #{node.kind}, #{@root.kind}"
      next if node.kind == "padding"

      if @root.kind == 'union'
        tag = i
        path = SignalClass.path_from_root(@root)
        if ahash["UNION"].has_key?(path)
          if ahash["UNION"][path].has_key?(node.name)
            tag = ahash["UNION"][path][node.name]
          end
        end

        @recstr  << "#{ind(2)}#{if_} tag is #{tag}:\n"
        @sendstr << "#{ind(2)}#{if_} tag is #{tag}:\n"
        if_ = "elif"
        i += 1
        @ind += 1
      end

      case node.kind
      when "numeric", "boolean"
        visit_numeric(ahash, node)
      when "enum"
        visit_enum(ahash, node)
      when "array"
        visit_array(ahash, node)
      when "struct", "union"
        visit_struct(ahash, node)
      end

      if @root.kind == 'union'
        pad = @root.size - node.size
        @recstr  << "#{ind(2)}reader.pad(#{pad})\n"
        @sendstr  << "#{ind(2)}writer.pad(#{pad})\n"
        @ind -= 1
      end

    end

    if @root.kind == 'union'
      @recstr  << "#{ind(2)}else:\n"
      @recstr  << "#{ind(3)}raise Exception('unknown union selector')\n"
      @sendstr << "#{ind(2)}else:\n"
      @sendstr << "#{ind(3)}raise Exception('unknown union selector')\n"
    end

    if @root.children.length == 1
      @recstr  << "#{ind(2)}pass\n"
      @sendstr << "#{ind(2)}pass\n"
    else
      @recstr  << "#{ind(2)}reader.align(#{@root.align})\n"
      @sendstr << "#{ind(2)}writer.align(#{@root.align})\n"
    end
  end

  def s
    @s
  end

  def generate(ahash)
    guess_dyn_array(ahash)
    generate_signal_class
    generate_attr_list(ahash)
    generate_constructor(ahash)
    generate_unserialize_prelude
    generate_serialize_prelude
    visit_nodes(ahash)
    @s << @sendstr + @recstr
    @file.puts @s
  end

end

