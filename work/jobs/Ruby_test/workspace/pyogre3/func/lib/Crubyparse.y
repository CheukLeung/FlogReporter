#
# C to Ruby parser
#

class Crubyparse

token IDENTIFIER CONSTANT STRING_LITERAL SIZEOF
token PTR_OP INC_OP DEC_OP LEFT_OP RIGHT_OP LE_OP GE_OP EQ_OP NE_OP
token AND_OP OR_OP MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN ADD_ASSIGN
token SUB_ASSIGN LEFT_ASSIGN RIGHT_ASSIGN AND_ASSIGN
token XOR_ASSIGN OR_ASSIGN TYPE_NAME
token TYPEDEF EXTERN STATIC AUTO REGISTER
token CHAR SHORT INT LONG SIGNED UNSIGNED FLOAT DOUBLE CONST VOLATILE VOID
token STRUCT UNION ENUM ELLIPSIS
token CASE DEFAULT IF ELSE SWITCH WHILE DO FOR GOTO CONTINUE BREAK RETURN

start translation_unit

expect 5

rule

  primary_expression:  #returns a scalar (the value) ...
    IDENTIFIER             
  | CONSTANT               { return((val[0] =~ /^0[^\.]/) ? val[0].oct : val[0]) } #hex, octal, bin conversion
  | STRING_LITERAL         { return(val[0]) }
  | '(' expression ')'     { return(val[1]) }

  postfix_expression:  #returns a scalar (the value) ... TBD
    primary_expression				{ return(val[0]) }
  | postfix_expression '[' expression ']'
  | postfix_expression '(' ')'
  | postfix_expression '(' argument_expression_list ')'
  | postfix_expression '.' IDENTIFIER
  | postfix_expression PTR_OP IDENTIFIER
  | postfix_expression INC_OP
  | postfix_expression DEC_OP

  argument_expression_list:  #returns a scalar (the value) ... TBD
    assignment_expression		        { return(val[0]) }
  | argument_expression_list ',' assignment_expression

  unary_expression:   #returns a scalar (the value) ... TBD
    postfix_expression				{ return(val[0]) }
  | INC_OP unary_expression			{ return(val[1].to_i + 1) }
  | DEC_OP unary_expression			{ return(val[1].to_i - 1) }
  | unary_operator cast_expression		{ if val[0].eql?'-'
                                                    return(-val[1].to_i)
                                                  elsif val[0].eql?'+'
                                                    return( val[1].to_i) 
                                                  elsif val[0].eql?'~'
                                                    return(~(val[1].to_i)) 
                                                  elsif val[0].eql?'!'
                                                    return(val[1].to_i > 0 ? 0 : 1)
                                                  else
                                                    return(val[1].to_i) 
                                                  end }
  | SIZEOF unary_expression			# TBD TBD TBD TBD TBD 
  | SIZEOF '(' type_name ')'			# Not really possible to do

unary_operator: 
    '&'
  | '*'
  | '+'
  | '-'
  | '~'
  | '!'

cast_expression:      #returns a scalar (the value) ... TBD cast ignored!
    unary_expression	 			{ return(val[0]) }
  | '(' type_name ')' cast_expression		{ return(val[1]) }  #TBD

multiplicative_expression:    #returns a scalar (the value)
    cast_expression				    { return(val[0])          }
  | multiplicative_expression '*' cast_expression   { return(val[0].to_i * val[2].to_i) }
  | multiplicative_expression '/' cast_expression   { return(val[0].to_i / val[2].to_i) }
  | multiplicative_expression '%' cast_expression   { return(val[0].to_i % val[2].to_i) }

additive_expression:          #returns a scalar (the value)
    multiplicative_expression			        { return(val[0])        }
  | additive_expression '+' multiplicative_expression   { return(val[0].to_i + val[2].to_i) }
  | additive_expression '-' multiplicative_expression   { return(val[0].to_i - val[2].to_i) }

shift_expression:             #returns a scalar (the value)
    additive_expression				    { return(val[0])                     }
  | shift_expression LEFT_OP additive_expression    { return(val[0].to_i << val[2].to_i) }
  | shift_expression RIGHT_OP additive_expression   { return(val[0].to_i >> val[2].to_i) }

relational_expression:        #returns a scalar (the value)
    shift_expression				    { return(val[0])                               }
  | relational_expression '<' shift_expression	    { return((val[0].to_i <  val[2].to_i) ? 1 : 0) }
  | relational_expression '>' shift_expression      { return((val[0].to_i >  val[2].to_i) ? 1 : 0) }
  | relational_expression LE_OP shift_expression    { return((val[0].to_i <= val[2].to_i) ? 1 : 0) }
  | relational_expression GE_OP shift_expression    { return((val[0].to_i >= val[2].to_i) ? 1 : 0) }

equality_expression:          #returns a scalar (the value)
    relational_expression			    { return(val[0])                               }
  | equality_expression EQ_OP relational_expression { return((val[0].to_i == val[2].to_i) ? 1 : 0) }
  | equality_expression NE_OP relational_expression { return((val[0].to_i != val[2].to_i) ? 1 : 0) }

and_expression:               #returns a scalar (the value)
    equality_expression				{ return(val[0])                    }
  | and_expression '&' equality_expression	{ return(val[0].to_i & val[2].to_i) }

exclusive_or_expression:      #returns a scalar (the value)
    and_expression				{ return(val[0])                    }
  | exclusive_or_expression '^' and_expression	{ return(val[0].to_i ^ val[2].to_i) }

inclusive_or_expression:      #returns a scalar (the value)
    exclusive_or_expression		 	         { return(val[0])                    }
  | inclusive_or_expression '|' exclusive_or_expression  { return(val[0].to_i | val[2].to_i) }

logical_and_expression:       #returns a scalar (the value)
    inclusive_or_expression			           { return(val[0])                     }
  | logical_and_expression AND_OP inclusive_or_expression  { return(((val[0].to_i > 0) && (val[2].to_i > 0)) ? 1 : 0) }

logical_or_expression:        #returns a scalar (the value)
    logical_and_expression			           { return(val[0])          }
  | logical_or_expression OR_OP logical_and_expression     { return(((val[0].to_i > 0) || (val[2].to_i > 0)) ? 1 : 0) }

conditional_expression:       #returns a scalar (the value)
    logical_or_expression			           { return(val[0])          }
  | logical_or_expression '?' expression ':' conditional_expression  { return((val[0].to_i > 0) ? val[2] : val[4]) }

assignment_expression:
    conditional_expression
  | unary_expression assignment_operator assignment_expression

assignment_operator:
    '='
  | MUL_ASSIGN
  | DIV_ASSIGN
  | MOD_ASSIGN
  | ADD_ASSIGN
  | SUB_ASSIGN
  | LEFT_ASSIGN
  | RIGHT_ASSIGN
  | AND_ASSIGN
  | XOR_ASSIGN
  | OR_ASSIGN

expression:
    assignment_expression
  | expression ',' assignment_expression

constant_expression:            # Returns a scalar (the value)
    conditional_expression	{ return(val[0]) }

declaration:
    declaration_specifiers ';'	          # we have this e.g. in "struct st {int a};"
  | declaration_specifiers init_declarator_list ';' { declare(val[0], val[1]) }

declaration_specifiers:         # Returns a hash describing the base type and storage
    storage_class_specifier			                { return(merge_hashes(val[0], {'.type' => 'int'})) }
  | storage_class_specifier declaration_specifiers  { return(merge_hashes(val[0], val[1])) }
  | type_specifier				                      { return(val[0]) }
  | type_specifier declaration_specifiers	          { return(merge_hashes(val[0], val[1])) }
  | type_qualifier				                      { return(merge_hashes(val[0], {'.type' => 'int'})) }
  | type_qualifier declaration_specifiers	          { return(merge_hashes(val[0], val[1])) }

init_declarator_list:           # Returns an array of [identifier,HashRef] pairs (1 per identifier)
    init_declarator 			     { return ([val[0]]) }
  | init_declarator_list ',' init_declarator { return (val[0].push(val[2])) }

init_declarator:
    declarator			{ return(val[0]) }
  | declarator '=' initializer	{ return(val[0]) }

storage_class_specifier:        # Returns a hash (key:.storage)
    TYPEDEF			{ return({'.storage' => val[0]}) }
  | EXTERN			{ return({'.storage' => val[0]}) }
  | STATIC			{ return({'.storage' => val[0]}) }
  | AUTO			{ return({'.storage' => val[0]}) }
  | REGISTER			{ return({'.storage' => val[0]}) }

type_specifier:                 # Returns a hash (key:.type or contructed type hash)
    VOID 			{ return({'.type' => val[0]}) }  #type:VOID
  | CHAR 			{ return({'.type' => val[0]}) }  #type:CHAR
  | SHORT INT			{ return({'.type' => val[0]}) }  #type:SHORT
  | SHORT    			{ return({'.type' => val[0]}) }  #type:SHORT
  | INT 			{ return({'.type' => val[0]}) }  #type:INT 
  | LONG LONG			{ return({'.type' => 'longlong'}) }  #type:LONGLONG
  | LONG INT			{ return({'.type' => val[0]}) }  #type:LONG
  | LONG    	 		{ return({'.type' => val[0]}) }  #type:LONG
  | FLOAT 			{ return({'.type' => val[0]}) }  #type:FLOAT
  | LONG DOUBLE 		{ return({'.type' => val[1]}) }  #type:DOUBLE
  | DOUBLE 			{ return({'.type' => val[0]}) }  #type:DOUBLE
  | SIGNED 			{ return({'.type' => 'int', '.signed' => 'signed'}) }   # Type is 'int' if no other type follow
  | UNSIGNED 			{ return({'.type' => 'int', '.signed' => 'unsigned'}) }   # Type is 'int' if no other type follow
  | struct_or_union_specifier   { return(val[0]) }  #struct or union
  | enum_specifier              { return(val[0]) }  #enum
  | TYPE_NAME 			{ return(get_table(@@typedef_table, val[0])) }

struct_or_union_specifier:      # Returns a hash describing the struct/union 
    struct_or_union IDENTIFIER '{'  # Struct tag created now, in case of recursion
              { typeval = _values[-3].clone
                nameval = _values[-2].clone
                table = (typeval['.type'].eql?'union') ? @@uniontag_table : @@structtag_table
                insert_table(table, nameval, {}) }
    struct_declaration_list '}'     # rest of rule
              { table = (val[0]['.type'].eql?'union') ? @@uniontag_table : @@structtag_table
                insert_table(table, val[1], struct_union_construct(val[0], \
                             val[4]).merge({'.type_or_id_name' => "(Struct/Union): #{val[1]}"}))
		c = get_table(table, val[1])
		if c.nil?
                  insert_table(table, val[1], {'.type' => val[0]['.type']}) 
                end 
                return c }
  | struct_or_union '{' struct_declaration_list '}' 
              { return struct_union_construct(val[0], val[2]) }
  | struct_or_union IDENTIFIER
              { table = (val[0]['.type'].eql?'union') ? @@uniontag_table : @@structtag_table
                c = get_table(table, val[1])
                if c.nil?
                  insert_table(table, val[1], {'.type' => val[0]['.type'], '.type_or_id_name' => "(Struct/Union): #{val[1]}"}) 
                  c = get_table(table, val[1])
                end 
                return c }

struct_or_union:                # Returns a hash (key:.type set to UNION or STRUCT)
    STRUCT 			{ return({'.type' => val[0]}) }  #type: STRUCT:
  | UNION			{ return({'.type' => val[0]}) }  #type: UNION :

struct_declaration_list:        # Returns an array of [identifier, type_descr_hash]
    struct_declaration				  { return(val[0]) }
  | struct_declaration_list struct_declaration	  { val[1].each { |elem| val[0].push(elem) }; return val[0] }

struct_declaration:             # Returns an array of [identifier, type_descr_hash]
    specifier_qualifier_list struct_declarator_list ';'  { return(struct_union_declare(val[0], val[1])) }

specifier_qualifier_list:       # Returns a hash describing the base type and storage
    type_specifier specifier_qualifier_list	  { return(merge_hashes(val[0], val[1])) }
  | type_specifier				  { return(val[0]) }
  | type_qualifier specifier_qualifier_list	  { return(merge_hashes(val[0], val[1])) }
  | type_qualifier				  { return(val[0]) }

struct_declarator_list:         # Array containing [identifier,HashRef] pairs (1 per identifier)
    struct_declarator				  { return([val[0]]) }
  | struct_declarator_list ',' struct_declarator  { return(val[0].push(val[2])) }

struct_declarator:              # Array containing the identifier and the type modifier descr hash (array,func, ptr)
    declarator					  { return(val[0]) }
  | ':' constant_expression			  # Bit field: TBD
  | declarator ':' constant_expression		  # Bit field: TBD

enum_specifier:
    ENUM '{' enumerator_list '}'            
	{ return({'.type' =>'enum', '.values'=> create_enum_hash(val[2])}) }
#  | ENUM IDENTIFIER '{' enumerator_list '}' 
#        { puts "Enum2";insert_table(@@enumtag_table, val[1], {'.type'=>'enum', '.values' => create_enum_hash(val[3]),'.type_or_id_name'=>"(enum): #{val[1]}"}) }

  | ENUM IDENTIFIER '{' enumerator_list '}' 
        { c = get_table(@@enumtag_table, val[1])
          if c.nil?
            c = insert_table(@@enumtag_table, val[1], {'.type'=>'enum', '.values' => create_enum_hash(val[3]),'.type_or_id_name'=>"(enum): #{val[1]}"}) 
          end
          return c}

  | ENUM IDENTIFIER		 { c = get_table(@@enumtag_table, val[1])
                                   if c.nil?
                                     insert_table(@@enumtag_table, val[1], {})
                                   end
                                   return c }

enumerator_list:            # Return an array of enum_constants  where an enum constant is [identifier, value]
    enumerator				   { return([val[0]]) }
  | enumerator_list ',' enumerator	   { return(val[0].push(val[2])) }

enumerator:                 # Return an array of 2 items: the identifier and the value (or nil): [identifier, value]
    IDENTIFIER				   { return([val[0], nil]) }
  | IDENTIFIER '=' constant_expression	   { return([val[0], val[2]]) }

type_qualifier:
    CONST			{ return({'.type_qualifier' => val[0]}) }
  | VOLATILE		{ return({'.type_qualifier' => val[0]}) }

declarator:                     # An array containing the identifier and the type modifier descr hash (array,func, ptr)
    pointer direct_declarator	{ return([val[1][0], link_type(val[1][1], val[0])]) }
  | direct_declarator		{ return(val[0]) }

direct_declarator:              # An array containing the identifier and the type modifier descr hash (array,func)
    IDENTIFIER 			{ return([val[0], nil]) }
  | '(' declarator ')'		{ return(val[1]) }
  | direct_declarator '[' constant_expression ']'
                                { return [val[0][0], link_type(val[0][1], {'.type' =>'array', '.array_size' => val[2]})] }
  | direct_declarator '[' ']'	#assume size 1 when unspecified (cant be part of signal anyway):
                                { return [val[0][0], link_type(val[0][1], {'.type' =>'array', '.array_size' => 1})] }
  | direct_declarator '(' parameter_type_list ')'
                                { return [val[0][0], link_type(val[0][1], {'.type' => 'function', '.input' => val[2]})] }
  | direct_declarator '(' identifier_list ')' 
                                { return [val[0][0], link_type(val[0][1], {'.type' => 'function', '.input' => val[2]})] }
  | direct_declarator '(' ')'   { return [val[0][0], link_type(val[0][1], {'.type' => 'function', '.input' => []})] }

pointer:                        # A hash chain (as deep as there are pointers)
    '*'				                  { return({'.type' =>'pointer'}) }
  | '*' type_qualifier_list	      { return( merge_hashes(val[1], {'.type' =>'pointer'})) }
  | '*' pointer 		               { return({'.type' =>'pointer', '.subtype'  => val[1]}) }
  | '*' type_qualifier_list pointer { return( merge_hashes(val[1], {'.type' =>'pointer', '.subtype' => val[2]}) ) }

type_qualifier_list:
    type_qualifier                      { return (val[0]) }
  | type_qualifier_list type_qualifier  { return (merge_hashes(val[0], val[1]))}

parameter_type_list:
    parameter_list              { return(val[0]) }
  | parameter_list ',' ELLIPSIS { return(val[0].push({'.type' => 'ellipsis'})) }

parameter_list:
    parameter_declaration                    { return([val[0]]) }
  | parameter_list ',' parameter_declaration { return(val[0].push(val[2])) }

parameter_declaration:
    declaration_specifiers declarator          { return(link_type(val[1][1], val[0])) }
  | declaration_specifiers abstract_declarator { return(link_type(val[1], val[0])) }
  | declaration_specifiers                     { return(val[0]) }

identifier_list:
    IDENTIFIER
  | identifier_list ',' IDENTIFIER

type_name:
    specifier_qualifier_list
  | specifier_qualifier_list abstract_declarator

abstract_declarator:
    pointer
  | direct_abstract_declarator
  | pointer direct_abstract_declarator

direct_abstract_declarator:
    '(' abstract_declarator ')'
  | '[' ']'
  | '[' constant_expression ']'
  | direct_abstract_declarator '[' ']'
  | direct_abstract_declarator '[' constant_expression ']'
  | '(' ')'
  | '(' parameter_type_list ')'
  | direct_abstract_declarator '(' ')'
  | direct_abstract_declarator '(' parameter_type_list ')'

initializer:
    assignment_expression
  | '{' initializer_list '}'
  | '{' initializer_list ',' '}'

initializer_list:
    initializer
  | initializer_list ',' initializer

statement:
    labeled_statement
  | compound_statement
  | expression_statement
  | selection_statement
  | iteration_statement
  | jump_statement

labeled_statement:
    IDENTIFIER ':' statement
  | CASE constant_expression ':' statement
  | DEFAULT ':' statement

compound_statement:
    '{' '}'
  | '{' statement_list '}'
  | '{' declaration_list '}'
  | '{' declaration_list statement_list '}'

declaration_list:
    declaration
  | declaration_list declaration

statement_list:
    statement
  | statement_list statement

expression_statement:
    ';'
  | expression ';'

selection_statement:
    IF '(' expression ')' statement
  | IF '(' expression ')' statement ELSE statement
  | SWITCH '(' expression ')' statement

iteration_statement:
    WHILE '(' expression ')' statement
  | DO statement WHILE '(' expression ')' ';'
  | FOR '(' expression_statement expression_statement ')' statement
  | FOR '(' expression_statement expression_statement expression ')' statement

jump_statement:
    GOTO IDENTIFIER ';'
  | CONTINUE ';'
  | BREAK ';'
  | RETURN ';'
  | RETURN expression ';'

translation_unit:
    external_declaration    { [@@symbol_table, @@structtag_table, @@typedef_table, @@uniontag_table, @@enumtag_table] }
  | translation_unit external_declaration  { [@@symbol_table, @@structtag_table, @@typedef_table, @@uniontag_table, @@enumtag_table] }

external_declaration:
    function_definition
  | declaration

function_definition:            #The actions specified here are for dropping declaration local to functions.
    declaration_specifiers declarator declaration_list { push_all_table_contexts() } compound_statement { pop_all_table_contexts() }
  | declaration_specifiers declarator { push_all_table_contexts() } compound_statement { pop_all_table_contexts() }
  | declarator declaration_list { push_all_table_contexts() } compound_statement { pop_all_table_contexts() }
  | declarator { push_all_table_contexts() } compound_statement { pop_all_table_contexts() }

end

########################################################################################
########################################################################################
##    
##      C Signal to Ruby Signal Parser
##
########################################################################################
######################################################################################## 
#
# This parser can process signal descriptions in the form of C header files, and extract
# the pertinent information to generate a corresponding signal description in Ruby.
#
# The parser does not generate any file contents directly. Instead it will collect all
# information into the 5 tables below. These tables are returned by the parser and it
# is intended that further processing will take place to generate the actual signal 
# description
#
# The tables contain info as follows:
# Symbol table:       variables and functions.
# Struct tag table:   tagged structs 
# Union tag table:    tagged unions
# Enum tag table:     tagged enums
# Typedef table:      typedefs
#
# The 5 tables are structured identically: 
# 'table_data' will hold the data as the parsing progresses. It is an array where new entries 
# always are inserted at the end. This arrangement makes it possible to handle entering and
# leaving local scopes correctly. Searching in the array is always done in reverse to find
# the latest entries first.
# Since searching an array may be time-consuming, the identifiers of all entries in 'table_data'
# are also entered into the 'quick-look' hash.
# 'stack' is an array onto which the number of current entries in the 'table_data' array will
# be appended each time a block is opened and deleted when it is closed. These numbers will be
# used to delete the correct entries from 'table_data' and 'quick_look'. 
# 'name' holds a name identifying the table.


---- header

@@symbol_table    = { 'table_data' => [], 'quick_look' => {}, 'stack' => [], 'name' =>"SYMBOL table" }
@@structtag_table = { 'table_data' => [], 'quick_look' => {}, 'stack' => [], 'name' =>"STRUCT TAG table" }
@@uniontag_table  = { 'table_data' => [], 'quick_look' => {}, 'stack' => [], 'name' =>"UNION TAG table" }
@@enumtag_table   = { 'table_data' => [], 'quick_look' => {}, 'stack' => [], 'name' =>"ENUM TAG table" }
@@typedef_table   = { 'table_data' => [], 'quick_look' => {}, 'stack' => [], 'name' =>"TYPEDEF table" }

@@latest_token = ''
@@line_number = 1
@@inputarr = []


---- inner

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
        @input = f.readlines.to_s
        do_parse
      end
    end

    return @@symbol_table, @@structtag_table, @@uniontag_table, @@enumtag_table, @@typedef_table

  end


  #
  # Lexer
  #
  def next_token
    a = []
  
    @lex_table = 
      [
       ['typedef\b',    :TYPEDEF],
       ['extern\b',     :EXTERN],
       ['static\b', 	:STATIC],
       ['auto\b', 	:AUTO],
       ['register\b', 	:REGISTER],
       ['char\b', 	:CHAR],
       ['short\b', 	:SHORT],
       ['int\b', 	:INT],
       ['long\b', 	:LONG],
       ['signed\b', 	:SIGNED],
       ['unsigned\b', 	:UNSIGNED],
       ['float\b', 	:FLOAT],
       ['double\b', 	:DOUBLE],
       ['const\b', 	:CONST],
       ['volatile\b', 	:VOLATILE],
       ['void\b', 	:VOID],
       ['struct\b', 	:STRUCT],
       ['union\b', 	:UNION],
       ['enum\b', 	:ENUM],
       ['\.\.\.', 	:ELLIPSIS],
       ['case\b', 	:CASE],
       ['default\b', 	:DEFAULT],
       ['if\b', 	:IF],
       ['else\b', 	:ELSE],
       ['switch\b', 	:SWITCH],
       ['while\b', 	:WHILE],
       ['do\b', 	:DO],
       ['for\b', 	:FOR],
       ['goto\b', 	:GOTO],
       ['continue\b', 	:CONTINUE],
       ['break\b', 	:BREAK],
       ['return\b', 	:RETURN],
       ['sizeof\b', 	:SIZEOF],
       ['0[xX][a-fA-F0-9]+',			   :CONSTANT], #hex constant
       ['0[0-9]+',				   :CONSTANT], #octal constant 
       ['(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?', :CONSTANT], #integer or floating point...
       ['"[^"]*"', 	:STRING_LITERAL], 
       ['->', 		:PTR_OP],
       ['\+\+', 	:INC_OP],
       ['--', 		:DEC_OP],
       ['<<', 		:LEFT_OP],
       ['>>', 		:RIGHT_OP],
       ['<=', 		:LE_OP],
       ['>=', 		:GE_OP],
       ['==', 		:EQ_OP],
       ['!=', 		:NE_OP],
       ['&&', 		:AND_OP],
       ['\|\|', 	:OR_OP],
       ['\*=', 		:MUL_ASSIGN],
       ['/=', 		:DIV_ASSIGN],
       ['%=', 		:MOD_ASSIGN],
       ['\+=', 		:ADD_ASSIGN],
       ['-=', 		:SUB_ASSIGN],
       ['<<=', 		:LEFT_ASSIGN],
       ['>>=', 		:RIGHT_ASSIGN],
       ['&=', 		:AND_ASSIGN],
       ['\^=', 		:XOR_ASSIGN],
       ['\|=', 		:OR_ASSIGN],
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

    # If an identifier was found, but it is a typename defined in the 
    # typedef_table, change the symbol from :IDENTIFIER to :TYPE_NAME.
    # (STRUCT, UNION and ENUM can never be followed by a typename)

    unless @@latest_token.eql?'STRUCT' or @@latest_token.eql?'UNION' or @@latest_token.eql?'ENUM' 
      if a[0].is_a?(Symbol) and a[0].id2name.eql?'IDENTIFIER' and 
         get_table(@@typedef_table, $1)
        a[0] = :TYPE_NAME
      end
    end

    if a[0].is_a?(Symbol)
      @@latest_token = a[0].id2name
    else
      @@latest_token = a[0]
    end

    return a

  end

---- footer

#
# Error report gets displayed on screen. If the parameter is omitted, will report
# a Syntax Error and cite the offending line. Otherwise, the text given in the
# parameter will be cited verbatim.
#
def error_report(text="")
  if text.eql?""
    puts "Syntax Error: \"#{@@inputarr[@@line_number-1]}\""
  else
    puts "#{text}"
  end
  puts
end

#
# Checks if an identifier is found in a table. Returns the value of the 
# identifier if found, else nil. The table is searched in reverse order
# to allow later entries to override previous entries.
#
def get_table(table, identifier)
  if table['quick_look'].has_key?(identifier)
    table['table_data'].reverse_each do |elem|
      return elem[1] if elem[0].eql?identifier
    end
  end
  return nil
end

#
# Inserts a new entry in the given table. 
# If the identifier already exists in the table, but its data is empty, 
# assigns the new data to it. If it already has data, this is seen
# as a redefinition and an error report is written.
#
def insert_table(table, identifier, data)

  if existing_data = get_table(table, identifier)
    if existing_data.empty? || !existing_data.has_key?(".members")
      data.each { |key, value| existing_data[key] = value }
      return data
    else
      error_report "Error in insert_table: Redefinition of #{identifier}"
      raise ParseError
    end
  end

  table['table_data'].push([identifier, data])
  table['quick_look'][identifier] = 1
  return data
end

#
# Follows the nested chain of hashes given in hash1 until it finds the last 
# (innermost) entry (which will not have a '.subtype' key). It creates such
# a key for this entry, and inserts the contents of hash2 as its value, thereby
# creating a new link in the chain, nested one level deeper.
# Returns the modified hash1.
#
def link_type(hash1, hash2)
  return hash1 if hash2.nil?
  return hash2 if hash1.nil?

  current = hash1

  while current.has_key?('.subtype')
    current = current['.subtype']
  end
  current['.subtype'] = hash2
  return hash1
end

def link_type_func(hash1, hash2)
  return hash1 if hash2.nil?
  return hash2 if hash1[1].nil?

  current = hash1[1]

  while current.has_key?('.subtype')
    current = current['.subtype']
  end
  current['.subtype'] = hash2
  return hash1
end



#
# Returns a hash of enum constants, where the key is the identifier and its value
# is the computed value, allowing for user defined enum assignments.
# A new entry is also inserted into the symbol table for each enum constant.
#
def create_enum_hash(enumarray)
  enum_value = -1
  enumhash = {}

  enumarray.each do |elem|
    if enumhash.has_key?(elem[0])
      error_report "Error in create_enum_list: Element redefinition: #{elem[0]}"
      raise ParseError
    end
    enum_value = (elem[1] == nil) ? enum_value + 1 : elem[1].to_i
    enumhash[elem[0]] = enum_value

    insert_table(@@symbol_table, elem[0], {'.type' =>'enum_const', '.value'=>enum_value, 
                 '.type_or_id_name' => "(Symbol): #{elem[0]}"})
  end

  return enumhash
end

#
# Returns a new hash consisting of hash2 merged to hash1. This means that
# duplicates will be overwritten.
#
def merge_hashes(hash1, hash2)
  merged_hash = hash1.clone
  return merged_hash if hash2.empty?

  h2 = hash2.clone
  
  if merged_hash.has_key?('.type_qualifier') && h2.has_key?('.type_qualifier') && merged_hash['.type_qualifier'] != h2['.type_qualifier']
    h2['.type_qualifier'] = merged_hash['.type_qualifier'] + ' ' + h2['.type_qualifier']
    #puts(h2['.type_qualifier'])
  end
  return merged_hash.merge!(h2)
end

#
# Function called when either a variable or a type is declared.
# For each member in the declarator_list, containing [identifier, hash chain] 
# pairs, the following is done:
# The base type is inserted at the end of the declarator chain, and a new
# entry is inserted into the appropriate table, either the symbol_table
# or the typedef table.
#
def declare(base_type, declarator_list)
  basetype = base_type.clone

  if basetype.has_key?('.storage') and basetype['.storage'].eql?'typedef'
    target_table = @@typedef_table
    target_type = 'Type'
  else
    target_table = @@symbol_table
    target_type = 'Symbol'
  end
  basetype.delete('.storage')

  declarator_list.each do |elem|
    current = elem[1]

    if !current.nil?
      while current.has_key?('.subtype') 
        current = current['.subtype']
      end
      current['.subtype'] = basetype
      data = elem[1].clone
    else
      data = basetype.clone
    end

    identifier = elem[0].clone
    if data.has_key?('.type_or_id_name')
      data['.base_ref_name'] = data['.type_or_id_name']
    end
    data['.type_or_id_name'] = "(#{target_type}): #{identifier}"
    insert_table(target_table, identifier, data)
  end
end

#
# Function called when a variable is declared inside a struct or union.
# For each member in the declarator_list, containing [identifier, hash chain] 
# pairs, the following is done:
# The base type is inserted at the end of the declarator chain, and a new
# entry is inserted into the array declare_array. This array is returned
# when the function finishes.
#
def struct_union_declare(base_type, declarator_list)
  basetype = base_type.clone
  declare_array = []

  declarator_list.each do |elem| 
    current = elem[1]

    if !current.nil?
      while current.has_key?('.subtype') 
        current = current['.subtype']
      end
      current['.subtype'] = basetype
      data = elem[1].clone
    else
      data = basetype
    end
    identifier = elem[0].clone
    declare_array.push([identifier, data])
  end

  return declare_array
end

#
# Returns a hash containing each member of a struct or union. Each
# member is represented as a name-type pair. The type is a chained
# hash describing a nested construct.
#
def struct_union_construct(base_type, member_list)
  con_hash = {'.type' => base_type['.type'].clone}  # struct or union 
  con_hash['.members'] = []

  member_list.each do |member|
    member_name = member[0]  # identifier
    member_type = member[1]  # chained hash

    con_hash['.members'].push([member_name, member_type])
  end

  return con_hash
end

#
# Pushes the context of a table onto the array "stack" when entering
# a function. What gets stored is not the actual contents of "table_data"
# but rather the number of elements currently present in "table_data".
# The contents of "table_data" is left unchanged.
#
def push_table_context(table)
  table['stack'].push(table['table_data'].length)
end

#
# Pushes the contexts of all tables onto their stacks
#
def push_all_table_contexts()
  [@@symbol_table, @@structtag_table, @@uniontag_table, @@enumtag_table, @@typedef_table].each do |table|
    push_table_context(table)
  end
end

#
# Pops the context back from "stack" when leaving a function. 
# The number of entries formerly present in "table_data" is popped
# off "stack", and this number of elements are then removed from
# the beginning of "table_data", leaving the rest unchanged.
# Since the removed elements are also present in the "quick_look"
# hash, these have to be removed also.
#
def pop_table_context(table)
  num_elem = table['stack'].pop
  removed = table['table_data'].slice!(0..num_elem-1)

  removed.each do |elem|
    table['quick_look'].delete(elem[0])
  end
end

#
# Pops the contexts of all tables from their stacks
#
def pop_all_table_contexts()
  [@@symbol_table, @@structtag_table, @@uniontag_table, @@enumtag_table, @@typedef_table].each do |table|
    pop_table_context(table)
  end
end

#
# Prints the contents of the val array
#
def pv(val)
  puts "\n*** VAL: *********************************************************"
  val.each_index do |index|
    puts " val[#{index}]="
    pp val[index]
  end
  puts "******************************************************************"
  puts
end

#
# Prints the contents of the tables
#
def pt()
  puts "\n*** TABLES: ******************************************************"
  [@@symbol_table, @@structtag_table, @@uniontag_table, @@enumtag_table, @@typedef_table].each {|t| pp t; puts}
  puts "******************************************************************"
  puts
end

#
# Prints the contents of the _values stack
#
def ps(_values)
  puts "\n*** _VALUES: *****************************************************"
  _values.each_index do |index|
    puts " _values[#{index}]="
    pp _values[index]
  end
  puts "******************************************************************"
  puts
end
