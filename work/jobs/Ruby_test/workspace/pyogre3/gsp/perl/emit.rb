require 'pp'

@@rd = "##{"-"*60}\n"
@@of = nil

#
# Create the hash containing signal structs and write it to file
#
class SignalHash

  def self.lastchild?(node)
    !node.parent.nil? && !node.parent.children.empty? &&
      node.parent.children[-2] == node
  end

  def self.indent(arr, blanks)
    str = ""
    arr.each {|line| str << " "*blanks + line}
    str
  end

  def self.array_indent_contribution(node)
    sum = 0
    p = node.parent
    return 0 if p.nil?
    until p.parent.nil?
      sum += 2 if p.kind.eql?("array")
      p = p.parent
    end
    sum
  end

  def self.path_from_root(node)
    s = node.name.clone
    t = node.name.clone
    p = node.parent
    until p.nil?
      if(p.kind.eql?("struct") && p.level == 0)
        s.insert(0, "#{p.s_u_name}.")
        x = p.kind.eql?('array') ? '[%d]' : ''
        t.insert(0, "#{p.s_u_name}#{x}.")
        p = p.parent
      else
        s.insert(0, "#{p.name}.")
        x = p.kind.eql?('array') ? '[%d]' : ''
        t.insert(0, "#{p.name}#{x}.")
        p = p.parent
      end
    end
    return s,t
  end

  def self.dense_union_in_array?(path, atable)
    atable["DENSE_UNION"].each do |e|
      t = e[0].split(".")[0..-2].join(".")
      if t.eql?(path)
        return "#{t.split(".")[1..-1].join(".")}.#{e[2]}"
      end	
    end
    ""
  end

  def self.dynamic_array?(node, atable)
    atable["ARRAY_SIZE"].each do |e|
      s,t = SignalHash.path_from_root(node)
      if s.eql?(e[0])
        tpath = t.split('.')
        p1 = tpath[1..-1].join('.')
        if tpath.length > 2
          p2 = "#{tpath[1..-2].join('.')}.#{e[1]}"
        else
          p2 = e[1]
        end
        return p1, p2, SignalHash.dense_union_in_array?(e[0], atable)
      end
    end    
    return "", "", ""
  end

  def self.selector_mapping(node, atable, path)
    selmap = {}
    count = 0
    node.children.each do |c|
      unless c.kind.eql?("padding") || c.kind.eql?("endmark")
        selmap[c.name] = count
        count += 1
      end
    end
    atable["SELECTOR_MAPPING"].each do |e|
      if e[0].eql?(path)
        if selmap.has_key?(e[2])
            selmap[e[2]] = e[1].to_i
        else
          raise "In SELECTOR_MAPPING: Union \'#{node.s_u_name}\' " +
            "has no member \'#{e[2]}\'" 
        end
      end
    end
    selvals = []
    selmap.each {|k,v| selvals << v}
    if selvals.length != selvals.uniq.length
      raise "In SELECTOR_MAPPING: Union \'#{node.s_u_name}\' " + 
        "has duplicate selector values assigned"
    else
      return selmap.invert
    end
  end

  def self.union_spec?(node, atable)
    path,t = SignalHash.path_from_root(node)
    atable["UNION_SELECTOR"].each do |e|
      if path.eql?(e[0])
        lst = e[0].split('.')
        p1 = lst[1..-1].join('.')
        return p1, e[1], SignalHash.selector_mapping(node, atable, path), ""
      end
    end
    atable["DENSE_UNION"].each do |e|
      if path.eql?(e[0])
        lst = e[0].split('.')
        p1 = lst[1..-1].join('.')
        return p1, e[1], SignalHash.selector_mapping(node, atable, path), e[2]
      end
    end
    return "","","",""
  end

  def self.extract_name(id)
    id =~ /\((.+)\): (\w+)/
    $2.clone
  end

  def self.emit_node(node, atable)
    a = []
    @r = ""
    comma = SignalHash.lastchild?(node) ? "" : ","
    d = SignalHash.array_indent_contribution(node)
    indlev = node.level > 1 ? 2*(3*node.level-1) : 2*(node.level+1)

    case node.kind
    when "numeric", "boolean"
      a << "{\n"
      a << "  \'#{node.name}\' => {\n"

      if node.kind.eql?("numeric") && node.basetype.eql?("OTHER")
        if node.data.has_key?(".type_or_id_name")
          a << "    \'.type_or_id_name\' => \'#{node.data[".type_or_id_name"]}\',\n"          
        end
        if node.data.has_key?(".signed")
          a << "    \'.signed\' => \'#{node.data[".signed"]}\',\n"
        end
        a << "    \'.type\' => \'#{node.data[".type"]}\',\n"
      else
        a << "    \'.type_or_id_name\' => \'(Type): #{node.basetype}\',\n"
        a << "    \'.signed\' => \'#{@@tt[node.basetype]["signed"]}\',\n"
        a << "    \'.type\' => \'#{@@tt[node.basetype]["type"]}\',\n"
      end
      a << "    \'.size\' => #{node.size},\n" 
      a << "    \'.align\' => #{node.align}\n"
      a << "  }\n"
      a << "}#{comma}\n"
      @r = SignalHash.indent(a, indlev+d)
    when "enum"
      a << "{\n"
      a << "  \'#{node.name}\' => {\n"
      a << "    \'.type_or_id_name\' => \'(enum): #{node.s_u_name}\',\n"
      a << "    \'.type\' => \'enum\',\n"
      a << "    \'.size\' => #{node.size},\n"
      a << "    \'.align\' => #{node.align},\n"
      a << "    \'.values\' => {\n"
      node.data.each do |e|
        a << "      \'#{e[0]}\' => #{e[1]}#{e == node.data.last ? "" : ","}\n"
      end
      a << "    }\n"
      a << "  }\n"
      a << "}#{comma}\n"
      @r = SignalHash.indent(a, indlev+d)
    when "array"
      arraypath, arraysizevar, denselenvar = SignalHash.dynamic_array?(node, atable)
      if node.leaf
        a << "{\n"
        a << "  \'#{node.name}\' => {\n"
        a << "    \'.array_size\' => #{node.arrsize},\n"
        a << "    \'.size\' => #{node.size},\n"
        a << "    \'.align\' => #{node.align},\n"
        a << "    \'.type\' => \'array\',\n"
        unless arraypath.empty?
          a << "    \'.dyn_info\' => {\n"
          a << "      \'.arraypath\' => \'#{arraypath}\',\n"
          a << "      \'.arraysizevar\' => \'#{arraysizevar}\'\n"
          a << "    },\n"           
        end
        a << "    \'.subtype\' => {\n"
        if node.basetype =~ /enum/
          a << "      \'.type_or_id_name\' => \'#{node.data[".type_or_id_name"]}\',\n"
          a << "      \'.type\' => \'#{node.data[".type"]}\',\n"
          a << "      \'.size\' => #{@@tt[node.data[".type"]]["size"]},\n"
          a << "      \'.align\' => #{@@tt[node.data[".type"]]["align"]}\n"
          a << "      \'.values\' => {\n"
          node.data[".values"].each do |e|
            a << "        \'#{e[0]}\' => #{e[1]}#{e == node.data[".values"].last ? "" : ","}\n"
          end
          a << "      }\n"
        elsif node.basetype =~ /OTHER/
          if node.data.has_key?(".type_or_id_name")
            a << "      \'.type_or_id_name\' => \'#{node.data[".type_or_id_name"]}\',\n"
          end
          if node.data.has_key?(".signed")
            a << "      \'.signed\' => \'#{node.data[".signed"]}\',\n"
          end
          a << "      \'.type\' => \'#{node.data[".type"]}\',\n"
          a << "      \'.size\' => #{@@nn[node.data[".type"]]["size"]},\n"
          a << "      \'.align\' => #{@@nn[node.data[".type"]]["align"]}\n"
        else
          a << "      \'.type_or_id_name\' => \'(Type): #{node.basetype}\',\n"
          a << "      \'.signed\' => \'#{@@tt[node.basetype]["signed"]}\',\n"
          a << "      \'.type\' => \'#{@@tt[node.basetype]["type"]}\',\n"
          a << "      \'.size\' => #{@@tt[node.basetype]["size"]},\n"
          a << "      \'.align\' => #{@@tt[node.basetype]["align"]}\n"
        end
        a << "    }\n"
        a << "  }\n"
        a << "}#{comma}\n"
        @r = SignalHash.indent(a, indlev+d)
      else  # array of structs or unions
        a << "{\n"
        a << "  \'#{node.name}\' => {\n"
        a << "    \'.array_size\' => #{node.arrsize},\n"
        a << "    \'.size\' => #{node.size},\n"
        a << "    \'.align\' => #{node.align},\n"
        a << "    \'.type\' => \'array\',\n"
        unless arraypath.empty?
          a << "    \'.dyn_info\' => {\n"
          a << "      \'.arraypath\' => \'#{arraypath}\',\n"
          a << "      \'.arraysizevar\' => \'#{arraysizevar}\'\n"
          a << "      \'.denselenvar\' => \'#{denselenvar}\'\n" unless denselenvar.empty?
          a << "    },\n"                     
        end
        a << "    \'.subtype\' => {\n"
        if node.s_u_name.eql?("__ANON__")
          a << "      \'.type\' => \'#{node.data}\',\n"
        else
          a << "      \'.type_or_id_name\' => \'(Struct/Union): #{node.s_u_name}\',\n"
          a << "      \'.type\' => \'#{node.basetype}\',\n"
        end
        a << "      \'.size\' => #{node.size/node.arrsize},\n"
        a << "      \'.align\' => #{node.align},\n"
        a << "      \'.members\' => [\n"
        @r = SignalHash.indent(a, indlev+d)
      end
    when "struct"
      if node.level == 0 # sigstruct 
        a << "\'.type_or_id_name\' => \'(Struct/Union): #{node.s_u_name}\',\n"
        a << "\'.size\' => #{node.size},\n"
        a << "\'.align\' => #{node.align},\n"
        a << "\'.type\' => \'#{node.kind}\',\n"
        a << "\'.members\' => [\n"
        @r = SignalHash.indent(a, 2*(node.level+1)+d)
      else
        a << "{\n"
        a << "  \'#{node.name}\' => {\n"
        unless node.s_u_name.eql?("__ANON__")
          a << "    \'.type_or_id_name\' => \'(Struct/Union): #{node.s_u_name}\',\n"
        end
        a << "    \'.size\' => #{node.size},\n"
        a << "    \'.align\' => #{node.align},\n"
        a << "    \'.type\' => \'#{node.kind}\',\n"
        a << "    \'.members\' => [\n"
        @r = SignalHash.indent(a, 2*(3*node.level-1)+d)
      end
    when "union"
      unionpath, unionselector, unionmembermap, denselenvar = SignalHash.union_spec?(node, atable)
      a << "{\n"
      a << "  \'#{node.name}\' => {\n"
      unless node.s_u_name.eql?("__ANON__")
        a << "    \'.type_or_id_name\' => \'(Struct/Union): #{node.s_u_name}\',\n"
      end
      a << "    \'.size\' => #{node.size},\n"
      a << "    \'.align\' => #{node.align},\n"
      a << "    \'.type\' => \'#{node.kind}\',\n"
      unless unionpath.empty?
        a << "    \'.union_info\' => {\n"
        a << "      \'.unionpath\' => \'#{unionpath}\',\n"
        a << "      \'.unionselector\' => \'#{unionselector}\',\n"
        a << "      \'.denselenvar\' => \'#{denselenvar}\',\n" unless denselenvar.empty?
        a << "      \'.unionmembermap\' => {\n"
        unionmembermap.each do |k,v|
          a << "        #{k} => \'#{v}\',\n"
        end
        a[-1] = a[-1][0..-3] + "\n"
        a << "      }\n"
        a << "    },\n"
      end
      a << "    \'.members\' => [\n"
      @r = SignalHash.indent(a, 2*(3*node.level-1)+d)
    when "padding"
      a << "{\n"
      a << "  \'+#{node.name}\' => \'#{node.size}\'\n"
      a << "}#{comma}\n"
      @r = SignalHash.indent(a, indlev+d)
    when "endmark"
      if node.level == 1
        @r << "  \]\n"
      else
        @r << "#{" "*(2*(3*node.level-2)+d)}]\n"
        if node.parent.kind.eql?("array")
          @r << "#{" "*(2*(3*node.level-3)+d)}\}\n"
          @r << "#{" "*(2*(3*node.level-4)+d)}\}\n"
          @r << "#{" "*(2*(3*node.level-5)+d)}\}" + 
            "#{SignalHash.lastchild?(node.parent) ? "" : ","}\n"
        else
          @r << "#{" "*(2*(3*node.level-3)+d)}\}\n"
          @r << "#{" "*(2*(3*node.level-4)+d)}\}" + 
            "#{SignalHash.lastchild?(node.parent) ? "" : ","}\n"
        end
      end
    end
    @r
  end

  def self.emit_signal(signal, sorted_signo, atable)
    @level = 1
    @s = ""
    @s << "\'#{signal["signo"]}\' => {\n"
    Tree.preorder(signal["tree"]) do |n|
      @s << SignalHash.emit_node(n, atable)
    end
    @s << "}"
    @s << "," unless signal["signo"] == sorted_signo[-1][1][1]
    @s << "\n"
    @@of.puts @s
  end

  def self.generate(sorted_signo, atable)
    @@of.puts "#{@@rd}# Signal data\n#{@@rd}"
    @@of.puts "our $data = {"
    sorted_signo.each {|e| emit_signal(@@grove[e[0]], sorted_signo, atable)}
    @@of.puts "};\n"
  end

end

#
# Generate the output file containing the signal description
#
class SignalDescription

  def initialize(atable, package, sorted_constant_name, sorted_signals,
                 sorted_signo, sorted_other_constant)
    @atable = atable
    @package = package
    @outfile = "#{Dir.pwd}/#{@package}.pm"
    @sorted_constant_name = sorted_constant_name
    @sorted_signals = sorted_signals
    @sorted_signo = sorted_signo
    @sorted_other_constant = sorted_other_constant
    @s = ""
  end

  def can_dyn_arr?(arr_node,root)
    n = arr_node
    check = false
    while n.parent
      return false if n.parent.kind == "array"
      n = n.parent
    end
    Tree.preorder(root) do |k|
      return false if check && k.level <= arr_node.level && k.name !~/endmark|padding/
      check = true if k==arr_node
    end
    return true
  end

  def implicit_arrays
    ahash = {}
    @atable["ARRAY_SIZE"].each {|e| ahash[e[0]] = e[1]}
    @@grove.each do |a,b|
      arr = []
      Tree.preorder(b["tree"]) {|n| arr << n}
      curr = nil
      arr.each do |n|
        path,t = SignalHash.path_from_root(n)
        prev = curr
        curr = n
        if n.kind.eql?('array') && n.arrsize == 1 && 
          !ahash.has_key?(path) && !prev.nil? &&
          (prev.parent == curr.parent) &&
          prev.kind.eql?('numeric') && (prev.basetype =~ /U\d+|S\d+/) &&
          !n.parent.kind.eql?('union') &&
          !(n.parent.children[0] == curr) &&
          can_dyn_arr?(n,b["tree"])
          @atable["ARRAY_SIZE"] << [path, prev.name]
        end
      end
    end
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
 
  def add_preamble
    @s = ""
    @s +=<<PREAMBLE
package #{@@options.package};

use strict;
use warnings;
use Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = ();
PREAMBLE
    @@of.puts @s
  end

  def add_export
    @s = ""
    @r = ""
    @v = ""

    @sorted_constant_name.each {|e| @r << "  #{e}\n"}

    @v +=<<VARS
  %constant
  %signame_by_no
  %signo_by_name
  $data
  $sigselect_template
VARS

    @s +=<<EXPORTS
our %EXPORT_TAGS = (
 constants => [
 qw/
#{@r}  /
 ],
 variables => [
 qw/
#{@v}  /
 ]
);
our @EXPORT_OK = qw(
#{@r}#{@v});

EXPORTS
    @@of.puts @s
  end

  def add_signal_name_constants
    @s = ""
    @sorted_signals.each do |e|
      @s << "sub #{e[0]} () { #{e[2]} }\n"
    end
    @@of.puts "#{@@rd}# Signal name constants\n#{@@rd}"
    @@of.puts @s + "\n"
  end

  def add_signal_name_hashmap
    @s = ""
    @r = ""
    @sorted_signals.each do |e|
      @r << "#{e[0]} => #{e[2]},\n"
    end
    @s +=<<NANO
our %signo_by_name = (
#{@r[0..-3]}
);

NANO
    @@of.puts "#{@@rd}# Hash-map: signal names to signal numbers\n#{@@rd}"
    @@of.puts @s
  end

  def add_other_constants
    @s = ""
    @sorted_other_constant.each do |e|
      @s << "sub #{e[0]} () { #{e[1]} }\n"
    end
    @@of.puts "#{@@rd}# Constants not associated " +
      "with signal numbers\n#{@@rd}"
    @@of.puts @s + "\n"
  end

  def add_other_hashmap
    @s = ""
    @r = ""
    @sorted_other_constant.each do |e|
      @r << "#{e[0]} => #{e[1]},\n"
    end
    @s +=<<OTHO
our %constant = (
#{@r[0..-3]}
);

OTHO
    @@of.puts "#{@@rd}# Hash-map: constants not associated " +
      "with signal numbers\n#{@@rd}"
    @@of.puts @s
  end

  def add_signo_hashmap
    @s = ""
    @r = ""
    @sorted_signals_by_signo = @sorted_signals.sort{|x,y| x[2]<=>y[2]}
    @sorted_signals_by_signo.each do |e|
      @r << "#{e[2]} => \"#{e[0]}\",\n"
    end
    @s +=<<NOON
our %signame_by_no = (
#{@r[0..-3]}
);

NOON
    @@of.puts "#{@@rd}# Hash-map: signal numbers to signal names\n#{@@rd}"
    @@of.puts @s
  end

  def add_dynamic_array_associations
    @s = ""
    @r = ""
    @atable["ARRAY_SIZE"].each do |e|
      @r << "[#{e[0]}, #{e[1]}, #{e[2]}],\n"
    end
    @s +=<<DAUA
our $dynamic_arrays = [
#{@r[0..-3]}
];

DAUA
    @@of.puts "#{@@rd}# Dynamic array specifications:\n# [Structname, Arrayname, Variablename]\n#{@@rd}"
    @@of.puts @s
  end

  def add_union_selector
    @s = ""
    @r = ""
    @atable["UNION_SELECTOR"].each do |e|
      @r << "[#{e[0]}, #{e[1]}, #{e[2]}],\n"
    end
    @s +=<<US
our $union_selectors = [
#{@r[0..-3]}
];

US
    @@of.puts "#{@@rd}# Union selector specifications:\n# [Structname, Unionname. Variablename]\n#{@@rd}"
    @@of.puts @s
  end

  def add_selector_mapping
    @s = ""
    @r = ""
    @atable["SELECTOR_MAPPING"].each do |e|
      @r << "[#{e[0]}, #{e[1]}, #{e[2]}],\n"
    end
    @s +=<<RA
our $selector_mappings = [
#{@r[0..-3]}
];

RA
    @@of.puts "#{@@rd}# Selector mapping specifications:\n# [Uniontagname, Selectorvalue, Membername]\n#{@@rd}"
    @@of.puts @s
  end

  def add_footer
    @s = ""
    sigsel = @@tt["SIGSELECT"]["size"] == 4 ? "\'N\'" : "\'n\'"
    @s +=<<FINISH

#----------------------------------------------------------------------------
# OSE Delta uses 32-bit SIGSELECT, OSE CK uses 16-bit.
#----------------------------------------------------------------------------
our $sigselect_template;
# Make it "constant".
*sigselect_template = \\#{sigsel};

sub import {
    my ($callpkg) = caller;
    my $pkg = shift;
    my @args = @_;

    my @to_export;
    foreach my $arg (@args) {
	if ($arg eq ':constants') {
	    foreach my $constant (@{$EXPORT_TAGS{constants}}) {
		unless (defined *{"${callpkg}::$constant"}) {
		    no strict;
		    *{"${callpkg}::$constant"} = \\&{"${pkg}::$constant"};
		    use strict;
		}
	    }
	}
	else {
	    push @to_export, $arg;
	}
    }
    
    __PACKAGE__->export_to_level(1, ($callpkg), @to_export);
}
    
1;
FINISH
    @@of.puts @s
  end

  def generate
    @@of = File.open(@outfile, "w")
    begin
      implicit_arrays
      add_header
      add_preamble
      add_export
      add_signal_name_constants
      add_signal_name_hashmap
      add_other_constants
      add_other_hashmap
      add_signo_hashmap
      SignalHash.generate(@sorted_signo, @atable)
      add_footer
      @@of.close
    rescue
      @@of.close
      File.delete(@outfile)
      raise
    end
  end

end
