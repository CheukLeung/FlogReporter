#
# Tree class. Contains methods for the following:
#   Generating a tree where each node may have an arbitrary number
#   of children. 
#   Traversing the tree.
#   Printing out the contents of tree nodes.
# 
class Tree

  attr_accessor :name, :kind, :basetype, :data, :arrsize, :s_u_name
  attr_accessor :leaf, :level, :size, :align, :parent, :children

  def initialize(name, kind, parent, arrsize=0)
    @name = name
    @kind = kind
    @basetype = nil
    @data = nil
    @arrsize = arrsize
    @s_u_name = ""
    @leaf = false
    @level = 0
    @size = 0
    @align = 0
    @parent = parent
    @children = []
  end

  def create_child(a)
    @children.push(a)
  end

  def is_leaf?
    @children.empty?
  end

  def self.has_child?(node, name)
    node.children.any? {|c| c.name.eql?(name)}
  end

  def self.get_child(node, name)
    node.children.each {|c| return c if c.name.eql?(name)}
    nil
  end

  def self.is_signo?(root, node)
    node == root.children[0] 
  end

  def self.printout(node)
    puts "name= #{node.name}"
    puts "kind= #{node.kind}"
    puts "basetype= #{node.basetype}"
    puts "arrsize= #{node.arrsize}"
    puts "s_u_name= #{node.s_u_name}"
    puts "leaf= #{node.leaf}"
    puts "level= #{node.level}"
    puts "size= #{node.size}"
    puts "align= #{node.align}"
    puts "parent= #{node.parent}"
    print "children= "
    node.children.each {|e| print e.name, " "}
    puts
  end

  def self.output_tier(arr, width) 
    format = "%-#{width}s"
    strarr = Array.new(11) {""}
    cmax = 0
    arr.each {|a| lmax = a.children.length; cmax = lmax if lmax > cmax}
    1.upto(cmax) {|i| strarr << ""} if cmax > 1
    arr.each do |a|
      strarr[0] << format % "name= #{a.name}"
      strarr[1] << format % "kind= #{a.kind}"
      strarr[2] << format % "btyp= #{a.basetype}"
      strarr[3] << format % "arsz= #{a.arrsize}"
      strarr[4] << format % "suna= #{a.s_u_name}"
      strarr[5] << format % "leaf= #{a.leaf}"
      strarr[6] << format % "levl= #{a.level}"
      strarr[7] << format % "size= #{a.size}"
      strarr[8] << format % "alig= #{a.align}"
      strarr[9] << format % "prnt= #{a.parent.nil? ? "" : a.parent.name}"
      strarr[10] << format % "chld= #{a.children.empty? ? "" : a.children[0].name}"
      if cmax > 1
        1.upto(cmax) do |i|
          strarr[10+i] << format % "      #{a.children.length > i ? a.children[i].name : ""}"
        end
      end
    end
    strarr.each {|x| puts x}
    puts
  end

  def self.level_print(node, width=16)
    arr = Array.new(Tree.height(node)+1) {[]}
    Tree.levelorder(node) do |n|
      arr[n.level].push(n)
    end
    puts
    arr.each {|a| Tree.output_tier(a, width)} 
    puts
    puts "*"*60
    puts
  end

  def self.height(node)
    startlevel = node.level
    height = 0
    Tree.preorder(node) do |n| 
      diff = n.level-startlevel;
      height = diff if diff > height  
    end
    height
  end

  def self.size(node)
    esize = 0
    Tree.preorder(node) {|n| esize += 1} 
    esize
  end

  def self.get_path(node)
    s = node.name.clone
    p = node.parent
    until p.parent.nil?
      s.insert(0, "#{p.name}.")
      p = p.parent
    end
    s
  end

  def self.preorder(node, &block)
    if block_given?
      yield(node)
    else
      Tree.printout(node)
    end
    unless node.children.empty?
      node.children.each {|n| Tree.preorder(n, &block)}
    end
  end

  def self.postorder(node, &block)
    unless node.children.empty?
      node.children.each {|n| Tree.postorder(n, &block)}
    end
    if block_given?
      yield(node)
    else
      Tree.printout(node)
    end
  end

  def self.levelorder_aux(node, level, &block)
    if level == 1
      if block_given?
        yield node
      else
        Tree.printout(node)
      end
    elsif level > 1
      node.children.each {|c| Tree.levelorder_aux(c, level-1, &block)}
    end
  end

  def self.levelorder(node, &block)
    for d in 1..Tree.height(node)+1
      Tree.levelorder_aux(node, d, &block)
    end
  end

end
