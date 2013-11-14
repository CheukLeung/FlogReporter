require 'singleton'
#
# Indentation levels are relative to the immediately preceding indentation level.
#
@@ind1 = " "*0
@@ind2 = @@ind1 + " "*4
@@ind3 = @@ind2 + " "*4
@@ind4 = @@ind3 + " "*4
@@ind5 = @@ind4 + " "*4

#
# Returns string where first char has been converted to uppercase, or
# downcase, respectively
#
class String

  def up
    self[0,1].upcase + self[1..-1]
  end

  def down
    self[0,1].downcase + self[1..-1]
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
# Signal class. Traverses the signal tree in preorder, assembling the Java
# class description in the process. The assembled text is written to a file
# when finished. 
# If internal nodes holding structs are encountered, RegularClass is called 
# to create files for these.
#
class SignalClass

  attr_reader :signo, :name

  def initialize(root, dirpath, package, signo, name, yamltab)
    @root = root
    @dirpath = dirpath
    @package = package
    @signo = signo
    @name = name
    @classname = name.up
    @yamltab = yamltab
    @recstr = ""
    @sendstr = ""
    @s = ""
    @filename = "#{@dirpath}/#{@root.name.up}.java"
    @regtally = Regtally.instance
  end

  #------------------------------------------------------------

  def add_package_declaration
    @s << "#{@@ind1}package #{@package};\n\n" unless @package.empty?
  end

  #------------------------------------------------------------

  def add_solo_signo_imports
    @s +=<<SOLO_IMPORTS
#{@@ind1}import enea.ose.system.UnlinkedSignal;
#{@@ind1}import se.ericsson.wcdma.rbs.boam.common.log.MessageLog;

SOLO_IMPORTS
  end

  #------------------------------------------------------------

  def add_common_imports
    @s +=<<COMMON_IMPORTS
#{@@ind1}import java.io.IOException;
#{@@ind1}import enea.ose.io.SignalInputStream;
#{@@ind1}import enea.ose.io.SignalOutputStream;
COMMON_IMPORTS
  end

  #------------------------------------------------------------

  def format_imports(val)
    str = ""
    val = [val] if val.kind_of?(String)
    val.each {|e| str << "import #{e};\n"}
    str
  end

  #------------------------------------------------------------

  def add_conditional_imports
    dtx = "#{@@ind1}import enea.ose.system.UnlinkedSignal;\n\n"

    unless @yamltab.nil?
      if @yamltab.has_key?(@classname)
        skey = @classname
      elsif @yamltab.has_key?("all_signals")
        skey = "all_signals"
      else
        skey = ""
      end

      unless skey.empty?
        if @yamltab[skey].has_key?("import")   
          if @yamltab[skey].has_key?("extends") && !@yamltab[skey]["extends"].empty?
            @s << format_imports(@yamltab[skey]["import"])
          else
            @s << dtx
            @s << format_imports(@yamltab[skey]["import"])
          end
          @s << "\n"
        else
          @s << dtx
        end
      else
        @s << dtx
      end
    else
      @s << dtx
    end
  end

  #------------------------------------------------------------

  def add_signal_class_declaration
    ext = "extends"
    pclass = "UnlinkedSignal"

    if solo_signo?
      @s << "#{@@ind1}public class #{@root.name.up} extends #{pclass} {\n"
    else
      unless @yamltab.nil?
        if @yamltab.has_key?(@classname)
          if @yamltab[@classname].has_key?(ext) && 
             !@yamltab[@classname][ext].empty?
            pclass = @yamltab[@classname][ext]
          end
        elsif @yamltab.has_key?("all_signals")
          if @yamltab["all_signals"].has_key?(ext) &&
             !@yamltab["all_signals"][ext].empty?
            pclass = @yamltab["all_signals"][ext]
          end
        end
      end
      @s << "#{@@ind1}public class #{@root.name.up} extends #{pclass} #{@@options.interface.empty? ? "" :"implements #{@@options.interface}"} {\n"
    end

  end

  #------------------------------------------------------------

  def add_signal_class_declaration_end
    @s << "#{@@ind1}}\n"
  end

  #------------------------------------------------------------

  def add_instance_variables
    if @root.children[0].kind.eql?("numeric") && 
       @root.children[0].basetype.eql?("SIGSELECT")
       @s << "#{@@ind2}public static final int SIG_NO = #{@signo};\n"
    end 
    @root.children[1..-1].each do |c|
      varname = c.name.down
      case c.kind
      when "numeric"
        @s << "#{@@ind2}public #{@@tt[c.basetype]["jtype"]} #{varname};\n"
      when "boolean"
        @s << "#{@@ind2}public boolean #{varname};\n"
      when "enum"
        @s << "#{@@ind2}public int #{varname};\n"
      when "struct"
        @s << "#{@@ind2}public #{c.s_u_name.up} #{varname} = new #{c.s_u_name.up}();\n"
      when "array"
        if c.leaf
          t = @@tt[c.basetype]["jtype"]
        elsif !c.s_u_name.empty?
          t = c.s_u_name.up
        end
        @s << "#{@@ind2}public #{t}[] #{varname};\n"
      end
    end
    @s << "#{@@ind2}\n"
  end

  #------------------------------------------------------------

  def add_default_constructor
    @s << "#{@@ind2}public #{@root.name.up}() {\n"
    @s << "#{@@ind3}super(SIG_NO);\n"
    @root.children[1..-1].each do |c|
      varname = c.name.down
      if c.kind =~ /array/
        if c.leaf
          t = @@tt[c.basetype]["jtype"]
        elsif !c.s_u_name.empty?
          t = c.s_u_name.up
        end
        @s << "#{@@ind3}#{varname} = new #{t}[#{c.arrsize}];\n"
      end
    end
    @s << "#{@@ind2}}\n\n"
  end

  #------------------------------------------------------------

  def fold(str)
    limit = 80
    poffset = str.index("(")
    strarr = str.split(",")
    @newstr = ""
    if strarr.length == 1
      @newstr = strarr[0]
      return @newstr
    end
    strarr.each_index do |i|
      if i == 0
        @newstr << strarr[i]
        @currpos = strarr[i].length
        if strarr.length == 2
          if @currpos + strarr[i+1].length < limit 
            @newstr << "," + strarr[i+1]          
          else
            @newstr << ",\n" + " "*poffset + strarr[i+1]
          end
          break        
        end
        if @currpos + strarr[i+1].length < limit 
          @newstr << "," + strarr[i+1]
          @currpos += 1 + strarr[i+1].length
        else
          @newstr << ",\n" + " "*poffset + strarr[i+1]
          @currpos = poffset + strarr[i+1].length
        end
        next
      end
      if i < strarr.length-1
        if @currpos + strarr[i+1].length < limit 
          @newstr << "," + strarr[i+1]
          @currpos += 1 + strarr[i+1].length
        else
          @newstr << ",\n" + " "*poffset + strarr[i+1]
          @currpos = poffset + strarr[i+1].length
        end
      else
        break
      end
    end
    @newstr
  end

  #------------------------------------------------------------

  def add_constructor
    return if solo_signo?
    argstr = ""
    assstr = ""
    @root.children[1..-1].each do |c|
      varname = c.name.down
      case c.kind
      when "numeric"
        argstr << "#{@@tt[c.basetype]["jtype"]} #{varname}, "
      when "boolean"
        argstr << "boolean #{varname}, "
      when "enum"
        argstr << "int #{varname}, "
      when "struct"
        argstr << "#{c.s_u_name.up} #{varname}, "
      when "array"
        if c.leaf
          argstr << "#{@@tt[c.basetype]["jtype"]}[] #{varname}, "
        elsif !c.s_u_name.empty?
          argstr << "#{c.s_u_name.up}[] #{varname}, "
        end
      end
      assstr << "#{@@ind3}this.#{varname} = #{varname};\n"
    end

    @s << fold("#{@@ind2}public #{@root.name.up}(#{argstr[0..-3]}) {\n")
    @s << "#{@@ind3}super(SIG_NO);\n"
    @s << assstr
    @s << "#{@@ind2}}\n\n"
  end

  #------------------------------------------------------------

  def format_block_literal(str)
    arr = str.split(/[\x0A]/)
    sind = arr[0] =~ /[^\s*#]/ ? 0 : 1
    rst = arr[sind..-1].join("\n")
    nst = rst.sub(/\@classname/, "#{@classname}")
  end

  #------------------------------------------------------------

  def add_initReceive_prelude
    @endianstr = @@endian.empty? ? "" : "SignalInputStream.#{@@endian}"
    @recstr +=<<REC_PRELUDE
#{@@ind2}public void initReceive() {
#{@@ind3}SignalInputStream in = getSignalInputStream(#{@endianstr});
#{@@ind3}try {
REC_PRELUDE
  end

  #------------------------------------------------------------

  def add_initReceive_postlude
    rex = "ioexception_rec"
    rtx = "#{@@ind4}e.printStackTrace();"

    unless @yamltab.nil?
      if @yamltab.has_key?(@classname)
        if @yamltab[@classname].has_key?(rex) &&
           !@yamltab[@classname][rex].empty?
          rtx = @yamltab[@classname][rex].chomp
        end
      elsif @yamltab.has_key?("all_signals")
        if @yamltab["all_signals"].has_key?(rex) &&
           !@yamltab["all_signals"][rex].empty?
          rtx = @yamltab["all_signals"][rex].chomp
        end
      end
    end

    @recstr +=<<REC_POSTLUDE
#{@@ind3}} catch (IOException e) {
#{format_block_literal(rtx)}
#{@@ind3}}
#{@@ind2}}

REC_POSTLUDE
  end
 
  #------------------------------------------------------------

  def add_initSend_prelude
    @endianstr = @@endian.empty? ? "" : "SignalOutputStream.#{@@endian}"
    @sendstr +=<<SEND_PRELUDE
#{@@ind2}public void initSend() {
#{@@ind3}SignalOutputStream out = getSignalOutputStream(#{@endianstr});
#{@@ind3}try {
SEND_PRELUDE
  end
 
  #------------------------------------------------------------

  def add_initSend_postlude
    sex = "ioexception_send"
    stx = "#{@@ind4}e.printStackTrace();"

    unless @yamltab.nil?
      if @yamltab.has_key?(@classname)
        if @yamltab[@classname].has_key?(sex) &&
           !@yamltab[@classname][sex].empty?
          stx = @yamltab[@classname][sex].chomp
        end
      elsif @yamltab.has_key?("all_signals")
        if @yamltab["all_signals"].has_key?(sex) &&
           !@yamltab["all_signals"][sex].empty?
          stx = @yamltab["all_signals"][sex].chomp
        end
      end
    end

    @sendstr +=<<SEND_POSTLUDE
#{@@ind3}} catch (IOException e) {
#{format_block_literal(stx)}
#{@@ind3}}
#{@@ind2}}
SEND_POSTLUDE
  end

  #------------------------------------------------------------

  def add_initReceive_for_solo_signo
    @recstr +=<<RECSOLO
#{@@ind2}public void initReceive() {
#{@@ind3}MessageLog.traceEnter(getClass(), \"#{@root.name.up} initReceive().\");
#{@@ind2}}

RECSOLO
  end

  #------------------------------------------------------------

  def add_initSend_for_solo_signo
    @recstr +=<<SENDSOLO
#{@@ind2}public void initSend() {
#{@@ind3}MessageLog.traceEnter(getClass(), \"#{@root.name.up} initSend().\");
#{@@ind2}}
SENDSOLO
  end

  #------------------------------------------------------------

  def visit_nodes(start, finish)
    curr = start
    loop do
    break if solo_signo?
      node = @parr[curr]
      @edges[node.level] = "#{node.name}"
      if node.kind.eql?("array") && !node.leaf
        esize = Tree.size(node)
        for i in 1..node.arrsize
          @edges[node.level] = "#{node.name}"
          @level = node.level
          path = @edges[1..@level].collect {|atom| "#{atom.down}."}.to_s[0..-2]
          @recstr << "#{@@ind4}#{path}[#{i-1}] = new #{node.s_u_name.up}();\n"
          @recstr << "#{@@ind4}in.align(#{node.align});\n"
          @sendstr << "#{@@ind4}out.align(#{node.align});\n"
          @edges[node.level] = "#{node.name}[#{i-1}]"
          @level = node.level + 1
          visit_nodes(curr+1, curr+esize-1)
        end
        unless @regtally.has?(node)
          regstruct = RegularClass.new(node, @dirpath, @package)
          regstruct.generate
          @regtally.add(node)
        end
        curr += esize
      else
        case node.kind
        when "numeric", "boolean", "enum", "array"
          @edges[node.level] = "#{node.name}"
          @level = node.level
          path = @edges[1..@level].collect {|atom| "#{atom.down}."}.to_s[0..-2]
          case node.kind
          when "numeric", "boolean"
            @recstr << "#{@@ind4}#{path} = in.read#{node.basetype}();\n"
            @sendstr << "#{@@ind4}out.write#{node.basetype}(#{path});\n"
          when "enum"
            @recstr << "#{@@ind4}#{path} = in.readS32();\n"
            @sendstr << "#{@@ind4}out.writeS32(#{path});\n"
          when "array"
            if node.basetype =~ /enum/
              @recstr << "#{@@ind4}#{path} = in.readS32Array(#{node.arrsize});\n"
              @sendstr << "#{@@ind4}out.writeS32Array(#{path});\n"
            else
              @recstr << "#{@@ind4}#{path} = in.read#{node.basetype}Array(#{node.arrsize});\n"
              @sendstr << "#{@@ind4}out.write#{node.basetype}Array(#{path});\n"
            end
          end
        when "struct"
          @recstr << "#{@@ind4}in.align(#{node.align});\n"
          @sendstr << "#{@@ind4}out.align(#{node.align});\n"
          unless @regtally.has?(node)
            regstruct = RegularClass.new(node, @dirpath, @package)
            regstruct.generate
            @regtally.add(node)
          end
        end
        curr += 1
      end
      break if curr > finish
    end
  end

  #------------------------------------------------------------

  def add_init_receive_and_init_send
    @edges = []
    @level = 1
    if solo_signo?
      add_initReceive_for_solo_signo
      add_initSend_for_solo_signo
    else
      add_initReceive_prelude
      add_initSend_prelude
      visit_nodes(2, Tree.size(@root)-1)
      add_initReceive_postlude
      add_initSend_postlude
    end
    @s << @recstr + @sendstr
  end

  #------------------------------------------------------------

  def write_to_file
    File.open(@filename, "w") {|f| f.puts @s}
  end

  #------------------------------------------------------------

  def s
    @s
  end

  #------------------------------------------------------------

  def make_sigarr
    @parr = []
    Tree.preorder(@root) {|n| @parr.push(n)}
  end

  #------------------------------------------------------------

  def solo_signo?
    @parr.length == 2
  end

  #------------------------------------------------------------

  def generate()
    make_sigarr
    add_package_declaration
    if solo_signo?
      add_solo_signo_imports
    else
      add_common_imports
      add_conditional_imports
    end
    add_signal_class_declaration
    add_instance_variables
    add_default_constructor
    add_constructor
    add_init_receive_and_init_send
    add_signal_class_declaration_end
    write_to_file
  end

end

#
# Regular class. When signal structs contain other structs,
# a regular class is generated for each of these.
#
class RegularClass

  def initialize(node, dirpath, package)
    @node = node
    @dirpath = dirpath
    @package = package
    @s = ""
    @filename = "#{@dirpath}/#{@node.s_u_name.up}.java"
  end

  #------------------------------------------------------------

  def add_package_declaration
    @s << "#{@@ind1}package #{@package};\n\n" unless @package.empty?
  end

  #------------------------------------------------------------

  def add_regular_class_declaration
    @s << "#{@@ind1}public class #{@node.s_u_name.up} {\n"
  end

  #------------------------------------------------------------

  def add_regular_class_declaration_end
    @s << "#{@@ind1}}\n"
  end

  #------------------------------------------------------------

  def add_instance_variables
    @node.children.each do |c|
      varname = c.name.down
      case c.kind
      when "numeric"
        @s << "#{@@ind2}public #{@@tt[c.basetype]["jtype"]} #{varname};\n"
      when "boolean"
        @s << "#{@@ind2}public boolean #{varname};\n"
      when "enum"
        @s << "#{@@ind2}public int #{varname};\n"
      when "struct"
        @s << "#{@@ind2}public #{c.s_u_name.up} #{varname} = new #{c.s_u_name.up}();\n"
      when "array"
        if c.leaf
          t = @@tt[c.basetype]["jtype"]
        elsif !c.s_u_name.empty?
          t = c.s_u_name.up
        end
        @s << "#{@@ind2}public #{t}[] #{varname} = new #{t}[#{c.arrsize}];\n"
      end
    end
    @s << "#{@@ind2}\n"
  end

  #------------------------------------------------------------

  def add_default_constructor
    @s << "#{@@ind2}public #{@node.s_u_name.up}() {}\n\n"
  end

  #------------------------------------------------------------

  def add_constructor
    argstr = ""
    assstr = ""
    @node.children.each do |c|
      varname = c.name.down
      case c.kind
      when "numeric"
        argstr << "#{@@tt[c.basetype]["jtype"]} #{varname}, "
      when "boolean"
        argstr << "boolean #{varname}, "
      when "enum"
        argstr << "int #{varname}, "
      when "struct"
        argstr << "#{c.s_u_name.up} #{varname}, "
      when "array"
        if c.leaf
          argstr << "#{@@tt[c.basetype]["jtype"]}[] #{varname}, "
        elsif !c.s_u_name.empty?
          argstr << "#{c.s_u_name.up}[] #{varname}, "
        end
      end
      assstr << "#{@@ind3}this.#{varname} = #{varname};\n"
    end
    @s << "#{@@ind2}public #{@node.s_u_name.up}(#{argstr[0..-3]}) {\n"
    @s << assstr
    @s << "#{@@ind2}}\n"
  end

  #------------------------------------------------------------

  def write_to_file
    File.open(@filename, "w") {|f| f.puts @s}
  end

  #------------------------------------------------------------

  def s
    @s
  end

  #------------------------------------------------------------

  def generate()
    add_package_declaration
    add_regular_class_declaration
    add_instance_variables
    add_default_constructor
    add_constructor
    add_regular_class_declaration_end
    write_to_file
  end

end
