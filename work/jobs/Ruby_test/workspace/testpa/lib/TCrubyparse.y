#
# Abstract TC text-files to Python test script and C signal file parser
#

class TCrubyparse

token IDENTIFIER CONSTANT SHORTNAME
token PTR_OP COL_ASSIGN 
token STATE TRANSITIONS   

#start abstractcase_list
start file

rule

  primary_expression:
    CONSTANT      #e.g. 5
  | IDENTIFIER    #e.g. BrakeSensor
  | '(' additive_expression ')'   { return(val[1]) }   #e.g. ( v - WABS * R )
  
  #postfix_expression:
  #  primary_expression
  #| postfix_expression '.' primary_expression
  #| postfix_expression '=' primary_expression
  
  current_state:
    STATE ':' '(' state_list ')'   { return(val[3]) }  #e.g. State: ( BrakeSensor.idle BrakeTorqueCalculator.idle WheelSensor.idle)

  state_list:
    state_item { return([val[0]]) }  #e.g. BrakeSensor.idle
  | state_list state_item   { return(val[0].push(val[1])) } #e.g. BrakeSensor.idle BrakeTorqueCalculator.idle

  state_item:
    primary_expression '.' primary_expression  { return({'.module' => val[0], '.state' => val[2]}) } #e.g. BrakeSensor.idle
   
  input_list:
    input_item { save_input(val[0]) ; return([val[0]]) }   #e.g. BrakeSensor.Pos = 0
  | input_list input_item  { save_input(val[1]) ; return(val[0].push(val[1])) }   #e.g. BrakeSensor.Pos = 0 BrakeTorqueCalculator.maxBr = 0

  input_item:
    primary_expression '.' primary_expression '=' primary_expression   { return({'.module' => val[0], '.parameter' => val[2], '.value' => val[4]}) }  #e.g. BrakeSensor.Pos = 0

  current_transition:
    TRANSITIONS ':' transitions_list  { return(val[2]) }  #e.g. Transitions: BrakeSensor.entry->BrakeSensor.exit { Pos := 0 }
    
  transitions_list:
    full_transition_item  #{  return([val[0]])  }          #e.g. BrakeSensor.idle -> BrakeSensor.entry
  | transitions_list full_transition_item    #{ return(val[0].push(val[1])) }  
  
  full_transition_item:
    part_transition_item  { return(val[0].push({'.empty' => 0})) }  #e.g. BrakeSensor.idle -> BrakeSensor.entry
  | part_transition_item '{' assignment_expression_list '}'   { return(val[0].push(val[2])) }  #e.g. BrakeSensor.entry -> BrakeSensor.exit { Pos := 0 }
  | part_transition_item '{' '}' { return(val[0].push({'.empty' => 0})) } #e.g. ABSFL.Exit->ABSFL.idle { }
  
  part_transition_item:
    state_item PTR_OP state_item { save_current_module(val[0]) ; return([val[0],val[2]]) } #e.g. BrakeSensor.idle -> BrakeSensor.entry
  
  assignment_expression_list:
    assignment_expression  {  return([val[0]])  }    #e.g. Pos := 0
  | assignment_expression_list ',' assignment_expression  {  return(val[0].push(val[2]))  }   #e.g. v > 0, tau, 1 or W:=Rpm*314/30, WheelTorque:=ReqTorque+0


  multiplicative_expression:    
    primary_expression				    { return(val[0]) }  #e.g. ReqTorque
  | multiplicative_expression '*' primary_expression   { i, j = to_integer(val[0], val[2]) ; return(i.to_i * j.to_i) }   #e.g. maxBr*Pos
  | multiplicative_expression '/' primary_expression   { i, j = to_integer(val[0], val[2]) ; return(i.to_i / j.to_i) }   #e.g. maxBr/Pos 
  
  additive_expression:  
    multiplicative_expression			        { return(val[0]) } #e.g. ReqTorque
  | additive_expression '+' multiplicative_expression   { i, j = to_integer(val[0], val[2]) ; return(i.to_i + j.to_i) }  #e.g. maxBr+Pos
  | additive_expression '-' multiplicative_expression   { i, j = to_integer(val[0], val[2]) ; return(i.to_i - j.to_i) }  #e.g. maxBr-Pos
    
  assignment_expression:
    additive_expression   { return(val[0])}  #{ i, j = to_integer(val[0], 0) ; return({'.parameter' => 'empty', '.operator' => 'empty', '.value' => i}) }  #e.g. tau or 0
  | primary_expression assignment_operator additive_expression   { i, j = to_integer(0, val[2]) ; return({'.parameter' => val[0], '.operator' => val[1], '.value' => j}) }   # ReqTorque := maxBr*Pos
  
  assignment_operator:
    '='
  | COL_ASSIGN  
  | '>'
  | '<'
  
  abstractcase_list:
    abstractcase 
  | abstractcase_list abstractcase 

  abstractcase:
    current_state input_list  { push_to_tables(val[0], val[1], {'.empty' => 0}) }   
  | current_state input_list current_transition   { push_to_tables(val[0], val[1], val[2])}   
  
  short_name:
    '[' SHORTNAME '=' IDENTIFIER ']' {set_current_name(val[3])}

  file:
    short_name abstractcase_list
end

########################################################################################
########################################################################################
##    
##  Abstract TestCase textfile to Python Concrete TestCase script and C Signal Parser
##
########################################################################################
######################################################################################## 
#
# This parser can process abstract test case descriptions in the form of text files with 
# blocks of current state, input to the next state, and which state we transition to. 
# The pertinent information about these blocks is extracted and generate a corresponding 
# signal description in C and a corresponding test case description in Python.
#
# The parser does not generate any file contents directly. Instead it will collect all
# information into the 3 tables below (state_list, input_list and transitions_list). 
# These tables are returned by the parser and the back end (code generator) will further 
# process the output and generate the actual signal and test script description.
#
# The tables contain info as follows:
# State table:          current states of the modules.
# Input table:          input for the next transition. 
# Transitions table:    current transition/s we are in.
#

---- header

# For the lexer
@@latest_token = ''
@@line_number = 1
@@inputarr = []

# 3 tables
@@state_list = []
@@input_list = []
@@transitions_list = []
@@name_list = []

# To find corresponding value for a variable
@@temp_input_list = {}
@@current_state = ''
@@current_file = ''

---- inner
   
  def initialize
    # For the lexer
    @@latest_token = ''
    @@line_number = 1
    @@inputarr = []

    # 3 tables
    @@state_list = []
    @@input_list = []
    @@transitions_list = []
    @@name_list = []

    # To find corresponding value for a variable
    @@temp_input_list = {}
    @@current_state = ''
    @@current_file = ''
  end
  
  #
  # Parser
  #
  def parse(input, options)

    @options = options
    @yydebug = true

    mode = "unreal"

    if mode == "unreal"
      @@inputarr = input.split(/\n/)
      @input = input
      do_parse
    else
      File.open("inputfile", "r") do |f|
        @input = f.readlines.join
        do_parse
      end
    end  
    # check_undefined
    return @@state_list, @@input_list, @@transitions_list, @@name_list

  end


  #
  # Lexer
  #
  def next_token
    a = []
  
    @lex_table = 
      [
       ['0[xX][a-fA-F0-9]+',			   :CONSTANT], #hex constant
       ['0[0-9]+',				   :CONSTANT], #octal constant 
       ['-?(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?', :CONSTANT], #integer or floating point...
       ['->', 		:PTR_OP],
       ['\:=', 		:COL_ASSIGN],
       ['State\b', 	:STATE],
       ['Transitions\b', 	:TRANSITIONS],
       ['SHORTNAME', :SHORTNAME],
       ['[_a-zA-Z]\w*', :IDENTIFIER],
      ]

    # Advance line number if a newline is seen
    if @input.match(/\A\s*(\n)\s*/)
      @@line_number += 1
    end

    # Discard white space and newlines
    @input.sub!(/\A[\s\n]+/, '')

    # Check for empty input and end of input
    if @input.empty?
      if @@latest_token == ''
        raise ParseError, "ParseError: Empty input file, terminating"
      else
        puts "End of input" if @options.debug
        return [false, false]
      end
    end
    
    @found = false
    
    # Scan lex table for match
    @lex_table.each do |elem|
      if @input.sub!(/\A(#{elem[0]})/, '')
        a = [elem[1], $1]
        @found = true
        break
      end
    end
      
    # Assume token is first single char in input
    if !@found 
      if @input.sub!(/(\A.)/, '')
        a = [$1, $1]
      end
    end

    if a[0].is_a?(Symbol)
      @@latest_token = a[0].id2name
    else
      @@latest_token = a[0]
    end

    return a

  end

  def on_error(t, val, vstack)
    args = "parse error on value " +
                            val.inspect + ' ' + token_to_str(t) + "\n"
    error_report "Error near line #{@@line_number} in \'trimmedcppfile\': #{args}"
  end

---- footer

#
# Save state, input and transition into separate arrays
#
def push_to_tables(current_state, current_input_list, current_transitions)
   @@state_list.push(current_state)
   @@input_list.push(current_input_list)
   @@transitions_list.push(current_transitions)   
   @@name_list.push("#{@@current_name}")
   
end

def set_current_name(name)
   @@current_name = name
end

#
# Save current input variables and their corresponding value
#
def save_input(input_item)
   if !@@temp_input_list.has_key?("#{input_item['.module']}")
      @@temp_input_list["#{input_item['.module']}"] = { "#{input_item['.parameter']}" => input_item['.value'] }
   else
      @@temp_input_list["#{input_item['.module']}"]["#{input_item['.parameter']}"] = input_item['.value']
   end
end

#
# Keeps track of current module 
#
def save_current_module(state_module)
   @@current_module = state_module['.module']
end

#
# Find corresponding value to a parameter
#
def to_integer(i, j)
   if ((i.is_a?(String)) && (i.to_i == 0))
      if ((i_to_integer = @@temp_input_list["#{@@current_module}"]["#{i}"]) == NIL)
         i_to_integer = i
      end
      if i == 'R' # hårdkodning
         i_to_integer = 1
      end
   else
      i_to_integer = i
   end
   if ((j.is_a?(String)) && (j.to_i == 0))
      if ((j_to_integer = @@temp_input_list["#{@@current_module}"]["#{j}"]) == NIL)
         j_to_integer = j
      end
      if j == 'R' # hårdkodning
         j_to_integer = 1
      end
   else
      j_to_integer = j
   end  
   return i_to_integer, j_to_integer
end

#
# Error report gets displayed on screen. If the parameter is omitted, will report
# a Syntax Error and cite the offending line. Otherwise, the text given in the
# parameter will be cited verbatim.
#
def error_report(text="")
  if text.eql?""
    puts "Syntax Error: \"#{@@inputarr[@@line_number-1]}\""
    #if @@options.debug
      write_error_report_to_file "Syntax Error: \"#{@@inputarr[@@line_number-1]}\""
    #end
  else
    puts "#{text}"
    #if @@options.debug
      write_error_report_to_file "#{text}"
    #end
  end
end

#
# Write all parsing errors to an error file 
#
def write_error_report_to_file(text)
   File.open("errorfile", "a") do |er|
      er.write "#{text}"
   end
end
    

