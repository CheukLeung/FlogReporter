require 'singleton'
require 'pp'
require 'set'
require 'tree'

#
# Indentation levels are relative to the immediately preceding indentation level.
#
@@ind=[]
@@ind[0] = " "*8
@@ind[1] = @@ind[0] + " "*1
@@ind[2] = @@ind[1] + " "*3
@@ind[3] = @@ind[2] + " "*3
@@ind[4] = @@ind[3] + " "*3
@@ind[5] = @@ind[4] + " "*3

#
# flags indicators for the existance of unions, sub-structures and dynamic arrays.
#
@@union_flag = false
@@dyn_array_flag = false
@@sub_struct_flag = false

#
# Returns string where first char has been converted to uppercase
#
class String
  def up
    self[0,1].upcase + self[1..-1]
  end
  def dn
    self.downcase
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
# Signal class. Traverses the signal tree in preorder, assembling the Erlang
# signal description in the process. The assembled text is written in two
# files when finished. # 
#
class SignalClass

  attr_reader :signo, :name

  def initialize(root, dirpath, package,signal_name_hash, association_table, signal_num_hash)
    @root = root
    @dirpath = dirpath
    @package = package
    @name_hash = signal_name_hash
    @recstr = ""
    @sendstr = ""
    @const = ""
    @enum =  "%%\n%% enumerations\n%%\n\n"
    @erl = ""
    @hrl = "%%\n%% Signals\n%%\n\n"
    @sig_sub = ""
    @sub = ""
    @head = ""
    @filename = package
    @filename_hrl = "#{@dirpath}/#{@filename}.hrl"
    @filename_erl = "#{@dirpath}/#{@filename}.erl"
    @regtally = Regtally.instance
    @assoc_table = association_table
    @signal_num_hash = signal_num_hash
    @un_arr = UnionArrayClass.new(@filename_erl,association_table,root)
  end

  # 
  # Traverses all nodes in the signal grove following pre-order.
  # For every signal, sub-structures, unions and enumeration
  # an equivalent Erlang description is given
  #
  def traverse(grove)
    @hf = ""
    @@options.header_files.each {|name| @hf << "%    #{name}\n"}
    args = (@@options.args.collect {|arg| arg + " "}).join

    @const +=<<HRL
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                              %
%                            SIGNAL DESCRIPTION                                %
%                                                                              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% WARNING: DO NOT MODIFY THIS FILE!!
% This file was automaticaly generated. Any modification will be lost the next
% time the generation occurs!
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This file was generated using #{$0}
% at #{Time.new}
% The following files were parsed:
#{@hf}
% The signal parser was called from the following directory (pwd).
%    #{`pwd`[0..-2]}
%
% The following signal parser command line was used:
% ruby #{$0} #{args}
%
% Used Ruby #{RUBY_VERSION}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


-hrl_name('#{@@options.package}').

HRL

    @const << "%%\n%% constants\n%%\n\n"

    @head +=<<HEADER
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                              %
%                            SIGNAL DESCRIPTION                                %
%                                                                              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% WARNING: DO NOT MODIFY THIS FILE!!
% This file was automaticaly generated. Any modification will be lost the next
% time the generation occurs!
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This file was generated using #{$0}
% at #{Time.new}
% The following files were parsed:
#{@hf}
% The signal parser was called from the following directory (pwd).
%    #{`pwd`[0..-2]}
%
% The following signal parser command line was used:
% ruby #{$0} #{args}
%
% Used Ruby #{RUBY_VERSION}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


HEADER

    @hrl << "\n\n"
    @erl << "-module('#{@@options.package}').\n\n"
    @erl << "-include(\"#{@@options.package}.hrl\").\n\n"
    @erl << "-export([type/1, type/2]).\n" 
    grove.each do |name,tree|
#      Tree.level_print(tree)
      signo = @name_hash[name]
      sig_name = @signal_num_hash[signo][1]
      Tree.preorder(tree) do |node|   
        if !node.is_leaf?
          case node.kind
            when "struct"
              if node.level == 0
                @sig_sub << "\ntype(?'#{sig_name}') -> '#{node.name}';"
                @sig_sub << "\ntype('#{node.name}') -> ?'#{node.name}';"
                @hrl << "-define(#{sig_name},#{signo}). %% 0x#{signo.to_s(16)}\n"
              else
                @sub << "\ntype('#{node.s_u_name}',_Path) -> ?'#{node.s_u_name}'(_Path);" unless @regtally.has?(node)
                @@sub_struct_flag = true
              end
            when "array"
                if is_dyn_arr?(node,@assoc_table)
                  @sub << "\ntype('#{node.s_u_name}',_Path) -> ?'#{node.s_u_name}'(_Path);" unless @regtally.has?(node)
                  @@dyn_array_flag = true if node.kind == "array" # I need to check the array here..
                else
#                  puts "ignored array: #{node.name}"
                end
            when "union"
              @sub << "\ntype('#{node.s_u_name}',_Path) -> ?'#{node.s_u_name}'(_Path);" unless @regtally.has?(node)
              @@union_flag = true
            else
              puts "unknown leaf node:#{node.kind}\n"
          end
          print_non_leaf(node)
        end
      end
    end
    @erl << "-export([union_type/2]).\n" if @@union_flag
    @erl << "-export([array_size/2]).\n\n" if @@dyn_array_flag
    @sig_sub.slice!(-1)
    @sig_sub << ".\n"
    @sub.slice!(-1) if @@sub_struct_flag 
    @sub << ".\n\n" if @@sub_struct_flag
  end
  
  #
  # returns a string without underscores and with the initial letter in uppercase.
  #
  def cap_name(name)
    node_name = ""
    name.split('_').each { |k| node_name << k.up}    
    node_name
  end
  #
  # check if an array is dynamic
  #
  def is_dyn_arr?(node,atable)
    #build path
    path = []
    path_string = ""
    while node.parent
      path.push(node.name) 
      node =  node.parent
    end
    path_string << node.name
    path.reverse_each {|p| path_string << "." + p}
    atable["ARRAY_SIZE"].each do |p,v|
      if p =~ /#{path_string}/
         return true
      end
    end
    return false
  end

  #
  # Creates an Erlang description for non-leaf nodes (structs,unions)
  #
  def print_non_leaf(node)
    # printer function for .hrl .erl non-leaf elements declarations
    if !@regtally.has?(node)
      node_name = node.s_u_name
      case node.kind
        when "struct", "array"
          @hrl << "-record('#{node_name}',{"  
          @erl << "-define('#{node_name}',\n" if node.level == 0
          @erl << "-define('#{node_name}'(Path),\n" if node.level > 0
          @erl << "#{@@ind[0]}{struct,'#{node_name}',\n"
        when "union"
   #       @hrl << "-record('#{node_name}',{"  
          @erl << "-define('#{node_name}'(Path),\n"
          @erl << "#{@@ind[0]}{union,'#{node_name}',\n"        
          @erl << "#{@@ind[0]} {?MODULE,union_type,[Path]},\n"
      end
      node.children.each do |n|
        print_element(n)
      end
      @regtally.add(node)
    end
  end


  #
  # give the path to a dynamic array or a union
  #
  def a_u_path(node)
    path = "["
    node_arr = []
    while node.parent
      node_arr.push(node.name)
      node = node.parent
    end 
    path << "'#{node.name}'"
    node_arr.reverse_each do |n|
      path << ",#{n}"
    end
    path << "]"
  end
 
  #
  # Printing an element of a data structure/signal
  #
  def print_element(node)
    @hrl << "#{node.name}," unless node.parent.kind == "union"
    basetype = ""
    case node.kind
      when "numeric" then
        if node.parent.children.rindex(node) == 0 and node.parent.children.length != 1 #first child
          @erl <<  "#{@@ind[1]}[{#{node.name},'#{node.basetype}'},\n"
        elsif  node.parent.children.rindex(node) == node.parent.children.length - 1 #last child
          @erl << " #{@@ind[1]}[" if node.parent.children.length==1
          @erl << " #{@@ind[1]}" unless node.parent.children.length==1
          @erl << "{#{node.name},'#{node.basetype}'}]"
          @erl << "}).\n\n"
          @hrl.slice!(-1) unless node.parent.kind == "union"
          @hrl << "}).\n" unless node.parent.kind == "union"
        else #intermediate child
          @erl << " #{@@ind[1]}{#{node.name},'#{node.basetype}'},\n"
        end
      when "array" then
        if is_dyn_arr?(node,@assoc_table)
          if node.basetype
             # simple dynamic array
            desc = "{#{node.name},{array,{?MODULE,array_size,['#{node.parent.name}','#{node.name}']},'#{node.basetype}'}}"         
          else
             # dynamic array of struct
             p = a_u_path(node)
             desc = (node.level == 1) ? 
               "{#{node.name},{array,{?MODULE,array_size,#{p}},?'#{node.s_u_name}'(#{p})}}" :
               "{#{node.name},{array,{?MODULE,array_size,[Path ++ [#{node.name}]]},?#{basetype}(Path ++ [#{node.name}])}}"
          end
#          desc = "{#{node.name},{array,{?MODULE,array_size,#{p}},?#{basetype}(#{p})}}"
        else
          if node.basetype
            # simple array
            basetype = "'#{node.basetype}'"
            desc = "{#{node.name},{array,#{node.arrsize},#{basetype}}}"
          else
            p = a_u_path(node)
            # array of struct, hard coded path for node.level == 1
            basetype = "'#{node.s_u_name}'"
            desc = (node.level == 1) ? 
              "{#{node.name},{array,{?MODULE,array_size,#{p}},?#{basetype}(#{p})}}" :
              "{#{node.name},{array,{?MODULE,array_size,[Path ++ [#{node.name}]]},?#{basetype}(Path ++ [#{node.name}])}}"
          end
        end
        if node.parent.children.rindex(node) == 0 and node.parent.children.length != 1 #first child
          @erl <<  "#{@@ind[1]}[#{desc},\n"
        elsif  node.parent.children.rindex(node) ==  node.parent.children.length - 1 #last child
          @erl << "#{@@ind[1]}[" if node.parent.children.length==1
          @erl << " #{@@ind[1]}" unless node.parent.children.length==1
          @erl << desc
          @erl << "]}).\n\n" 
          @hrl.slice!(-1) #if node.basetype
          @hrl << "}).\n" #if node.basetype
        else #intermediate child
          @erl <<  " #{@@ind[1]}#{desc},\n"  
        end
      when "struct"
        desc = "{#{node.name},?'#{node.s_u_name}'(['#{node.parent.name}',#{node.name}])}" if node.level == 1
        desc = "{#{node.name},?'#{node.s_u_name}'(Path)}" if node.level > 1       
        if node.parent.children.rindex(node) == 0 and node.parent.children.length != 1 #first child
          @erl <<  "#{@@ind[1]}[#{desc},\n"
        elsif  node.parent.children.rindex(node) ==  node.parent.children.length - 1 #last child
          @erl << " #{@@ind[1]}[" if node.parent.children.length==1
          @erl << " #{@@ind[1]}" unless node.parent.children.length==1
          @erl << "#{desc}]"
          @erl << "}).\n\n"
          @hrl.slice!(-1)
          @hrl << "}).\n"
        else #intermediate child
          @erl <<  " #{@@ind[1]}#{desc},\n"
        end
     when "union"
        p = a_u_path(node)
        desc = (node.level == 1) ? 
           "{#{node.name},?'#{node.s_u_name}'(#{p})}" :
           "{#{node.name},?'#{node.s_u_name}'(Path ++ [#{node.name}])}"
        if node.parent.children.rindex(node) == 0 and node.parent.children.length != 1 #first child
          @erl <<  "#{@@ind[1]}[#{desc},\n"
        elsif  node.parent.children.rindex(node) ==  node.parent.children.length - 1 #last child
          @erl << " #{@@ind[1]}[" if node.parent.children.length==1
          @erl << " #{@@ind[1]}" unless node.parent.children.length==1
          @erl <<  "#{desc}]"
          @erl << "}).\n\n"
#          @hrl.slice!(-1) #maybe I need them
#          @hrl << "}).\n"
        else #intermediate child
          @erl <<  " #{@@ind[1]}#{desc},\n"
        end 
      else
        puts "unknown data type: #{node.kind} as input\n\n"
    end
  end

   
  # 
  # Opens and writes the signal description in Erlang files .hrl, .erl
  #
  def write_to_file
    file = File.open(@filename_erl,"a")
    file.puts @head, @erl, @sig_sub
    file.puts @sub if @@sub_struct_flag
    (file.puts @un_arr.uni_def, @un_arr.uni_func, @un_arr.uni_func_2) if @@union_flag
    (file.puts @un_arr.arr_def, @un_arr.arr_func) if @@dyn_array_flag
    file.close
    File.open(@filename_hrl, "a") {|f| f.puts @const, @enum, @hrl}
  end

  def s
    @s
  end

  # 
  # Top level function to start signal description generation..
  #
  def generate()
    traverse(@root)
    @un_arr.traverseUnions if @@union_flag
    @un_arr.traverseArrays if @@dyn_array_flag
    write_to_file
  end

end

#
# Union Class. This class traverses the atable to find possible unions
# in the signal files. It prints the functions needed to make possible
# to include unions in a signal. The mapping between a union in a signal
# and its selector variable is described with a define derivative. If 
# no mapping is given in the signal file the default mapping (0,1,2,...)
# is used.
#
class UnionArrayClass
  
  attr_reader :uni_def, :uni_func, :uni_func_2, :arr_def, :arr_func

  def initialize(erl_file, assoc_table, tree)
    @uni_func = ""
    @uni_func_2 = ""
    @uni_def = "%%\n%% Union handling\n%%\n\n"
    @assoc_table = assoc_table
    @file = erl_file
    @tree = tree
    @arr_def = "%%\n%% Dynamic array handling\n%%\n"
    @arr_func = ""
  end

  #
  #  This method can find a node in the Grove when the dot notation
  #  location is given in an array or union directive. This solution
  #  is selected to avoid conflicts when structs are re-used.
  #
  def find_node(root,path)
    name_array = path.split('.')
    node = root[name_array[0]]
    name_array.each do |n|
      node.children.each do |c|
         if c.name == n
           node = c
           break
         end
      end
    end
    node
  end
  
  def path_to_name(path)
    name = ""
    name_array = []
    name_array = path.split('.')
    name_array.each { |n|  name << n.up }
    return name, name_array
  end

  def traverseUnions
    name = ""
    name_array = []
    flag = false #flag to identify union mapping given by the user
    counter = 0 #counter for default mapping
    @assoc_table["UNION_SELECTOR"].each do |a,b|
      name, name_array = path_to_name(a)
      @uni_def << "\n-define('#{name}',['#{name_array[0]}'"
      name_array.each { |n|  @uni_def << ",#{n}" unless name_array.rindex(n) == 0 }
      @uni_def << "])."
      @uni_def << "\n-define('#{name + "Selector"}',["
      node = find_node(@tree,a)
      selector = find_node(@tree,a + "." + b)
      @assoc_table["SELECTOR_MAPPING"].each do |u|
        if u[0] == a
          @uni_def << "{#{u[1]},#{u[2]}},"
          flag = true
        end
      end
      if !flag
        node.children.each do |c|
          @uni_def << "{#{counter},#{c.name}},"
          counter += 1
        end
      end
      @uni_def.slice!(-1)
      @uni_def << "]).\n"
      @uni_func +=<<UNION_FUNC
union_type(#'#{selector.parent.s_u_name}'{#{b} = Selector},?'#{name}') ->
    get_val(Selector,?'#{name + "Selector"}');
union_type(FVals,?'#{name}') ->
    get_union_type(#{selector.name},FVals,?'#{name + "Selector"}');
UNION_FUNC

      name = ""
      flag = false
      counter = 0
      name_array = []
    end 
    @uni_func.slice!(-2..-1)
    @uni_func << ".\n"
    @uni_func_2 +=<<FUNCTIONS

get_union_type(Field,FVals,Types) ->
    {Field,Selector} = lists:keyfind(Field,1,FVals),
    get_val(Selector,Types).
get_val(Key,KeyVals) ->
    {Key,Val} = lists:keyfind(Key,1,KeyVals),
    Val.
FUNCTIONS
  end

  def traverseArrays
    @assoc_table["ARRAY_SIZE"].each do |path,size_var|
      name, name_array = path_to_name(path)
      @arr_def << "\n-define('#{name}',['#{name_array[0]}'"
      name_array.each { |n|  @arr_def << ",#{n}" unless name_array.rindex(n) == 0 }
      @arr_def << "])."
      size_node = find_node(@tree,path + "." + size_var) 
#      size_node = find_node(@tree,size_var)
      @arr_func +=<<ARRAY_FUNC
array_size(#'#{size_node.parent.s_u_name}'{#{size_var} = Size},?'#{name}') ->
    Size;
array_size(FVals,?'#{name}') ->
    get_val(#{size_var},FVals);
ARRAY_FUNC
 
    end
    @arr_func.slice!(-2..-1)
    @arr_func << ".\n"
  end
end
