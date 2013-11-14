# GetRef.rb

@@ref_state_list_0 = [ 
   [{".state" => "someState", ".module" => "module1" },
   {".state" => "someState", ".module" => "module2" },
   {".state" => "someState", ".module" => "module3" }],
   [{".state" => "nextState", ".module" => "module1" },
   {".state" => "someState", ".module" => "module2" },
   {".state" => "someState", ".module" => "module3" }],
   [{".state" => "someOtherState", ".module" => "module1" },
   {".state" => "someState", ".module" => "module2" },
   {".state" => "someState", ".module" => "module3" }]
]

@@ref_input_list_0 = [
   [{".module"=>"module1", ".value"=>"0", ".parameter"=>"input_for_next_state1"},
   {".module"=>"module1", ".value"=>"0", ".parameter"=>"input_for_next_state2"},
   {".module"=>"module2", ".value"=>"0", ".parameter"=>"input_for_next_state1"},
   {".module"=>"module3", ".value"=>"0", ".parameter"=>"input_for_next_state1"},
   {".module"=>"module3", ".value"=>"0", ".parameter"=>"input_for_next_state2"},
   {".module"=>"module3", ".value"=>"0", ".parameter"=>"input_for_next_state3"}],
   [{".module"=>"module1", ".value"=>"0", ".parameter"=>"input_for_next_state1"},
   {".module"=>"module1", ".value"=>"0", ".parameter"=>"input_for_next_state2"},
   {".module"=>"module2", ".value"=>"0", ".parameter"=>"input_for_next_state1"},
   {".module"=>"module3", ".value"=>"0", ".parameter"=>"input_for_next_state1"},
   {".module"=>"module3", ".value"=>"0", ".parameter"=>"input_for_next_state2"},
   {".module"=>"module3", ".value"=>"0", ".parameter"=>"input_for_next_state3"}],
   [{".module"=>"module1", ".value"=>"6", ".parameter"=>"input_for_next_state1"},
   {".module"=>"module1", ".value"=>"0", ".parameter"=>"input_for_next_state2"},
   {".module"=>"module2", ".value"=>"0", ".parameter"=>"input_for_next_state1"},
   {".module"=>"module3", ".value"=>"0", ".parameter"=>"input_for_next_state1"},
   {".module"=>"module3", ".value"=>"0", ".parameter"=>"input_for_next_state2"},
   {".module"=>"module3", ".value"=>"0", ".parameter"=>"input_for_next_state3"}]
]

@@ref_transitions_list_0 = [
   [{".state"=>"someState", ".module"=>"module1"},
   {".state"=>"nextState", ".module"=>"module1"},
   {".empty"=>0}],
   [{".state"=>"nextState", ".module"=>"module1"},
   {".state"=>"someOtherState", ".module"=>"module1"},
   [{".parameter"=>"input_for_next_state1", ".operator"=>":=", ".value"=>"6"}]],
   [{".state"=>"nextState", ".module"=>"module1"},
   {".state"=>"someOtherState", ".module"=>"module1"},
   {".empty"=>0}]
]

@@ref_name_list_0 = [
    "abstractTC_template",
    "abstractTC_template",
    "abstractTC_template"
]

@@ref_state_list_1 = [ 
   [{".state" => "someState", ".module" => "module1" },
   {".state" => "someState", ".module" => "module2" },
   {".state" => "someState", ".module" => "module3" }],
   [{".state" => "nextState", ".module" => "module1" },
   {".state" => "someState", ".module" => "module2" },
   {".state" => "someState", ".module" => "module3" }],
   [{".state" => "someOtherState", ".module" => "module1" },
   {".state" => "someState", ".module" => "module2" },
   {".state" => "someState", ".module" => "module3" }]
]

@@ref_input_list_1 = [
   [{".module"=>"module1", ".value"=>"0", ".parameter"=>"input_for_next_state1"},
   {".module"=>"module1", ".value"=>"0", ".parameter"=>"input_for_next_state2"}],
   [{".module"=>"module1", ".value"=>"2", ".parameter"=>"input_for_next_state1"},
   {".module"=>"module1", ".value"=>"1", ".parameter"=>"input_for_next_state2"}],
   [{".module"=>"module1", ".value"=>"3", ".parameter"=>"input_for_next_state1"},
   {".module"=>"module1", ".value"=>"4", ".parameter"=>"input_for_next_state2"}]
]

@@ref_transitions_list_1 = [
   [{".state"=>"someState", ".module"=>"module1"},
   {".state"=>"nextState", ".module"=>"module1"},
   [{".parameter"=>"input_for_next_state1", ".operator"=>":=", ".value"=>"1"}]],
   [{".state"=>"nextState", ".module"=>"module1"},
   {".state"=>"someOtherState", ".module"=>"module1"},
   [{".parameter"=>"input_for_next_state1", ".operator"=>">", ".value"=>"2"}]],
   [{".state"=>"nextState", ".module"=>"module1"},
   {".state"=>"someOtherState", ".module"=>"module1"},
   [{".parameter"=>"input_for_next_state1", ".operator"=>"<", ".value"=>"3"}]]
]

@@ref_name_list_1 = [
    "tranisition_template",
    "tranisition_template",
    "tranisition_template"
]

@@ref_state_list_2 = [
    [{".module"=>"ABSFL", ".state"=>"idle"}],
    [{".module"=>"ABSFL", ".state"=>"Entry"}],
    [{".module"=>"ABSFL", ".state"=>"CalcSlipRate"}],
    [{".module"=>"ABSFL", ".state"=>"Exit"}],
    [{".module"=>"ABSFL", ".state"=>"idle"}]
]

@@ref_input_list_2 = [
    [{".module"=>"ABSFL", ".parameter"=>"w", ".value"=>"0"},
    {".module"=>"ABSFL", ".parameter"=>"wheelABS", ".value"=>"0"},
    {".module"=>"ABSFL", ".parameter"=>"torqueABS", ".value"=>"-1"},
    {".module"=>"ABSFL", ".parameter"=>"v", ".value"=>"0"},
    {".module"=>"ABSFL", ".parameter"=>"R", ".value"=>"1"}],
    [{".module"=>"ABSFL", ".parameter"=>"w", ".value"=>"8"},
    {".module"=>"ABSFL", ".parameter"=>"wheelABS", ".value"=>"1"},
    {".module"=>"ABSFL", ".parameter"=>"torqueABS", ".value"=>"-1"},
    {".module"=>"ABSFL", ".parameter"=>"v", ".value"=>"12"},
    {".module"=>"ABSFL", ".parameter"=>"R", ".value"=>"1"}],
    [{".module"=>"ABSFL", ".parameter"=>"w", ".value"=>"8"},
    {".module"=>"ABSFL", ".parameter"=>"wheelABS", ".value"=>"1"},
    {".module"=>"ABSFL", ".parameter"=>"torqueABS", ".value"=>"0"},
    {".module"=>"ABSFL", ".parameter"=>"v", ".value"=>"12"},
    {".module"=>"ABSFL", ".parameter"=>"R", ".value"=>"1"}],
    [{".module"=>"ABSFL", ".parameter"=>"w", ".value"=>"8"},
    {".module"=>"ABSFL", ".parameter"=>"wheelABS", ".value"=>"1"},
    {".module"=>"ABSFL", ".parameter"=>"torqueABS", ".value"=>"0"},
    {".module"=>"ABSFL", ".parameter"=>"v", ".value"=>"12"},
    {".module"=>"ABSFL", ".parameter"=>"R", ".value"=>"1"}],
    [{".module"=>"ABSFL", ".parameter"=>"w", ".value"=>"8"},
    {".module"=>"ABSFL", ".parameter"=>"wheelABS", ".value"=>"1"},
    {".module"=>"ABSFL", ".parameter"=>"torqueABS", ".value"=>"0"},
    {".module"=>"ABSFL", ".parameter"=>"v", ".value"=>"12"},
    {".module"=>"ABSFL", ".parameter"=>"R", ".value"=>"1"}]
]

@@ref_transitions_list_2 = [
    [{".module"=>"ABSFL", ".state"=>"idle"},
    {".module"=>"ABSFL", ".state"=>"Entry"},
    [{".parameter"=>"w", ".operator"=>":=", ".value"=>"8"},
    {".parameter"=>"wheelABS", ".operator"=>":=", ".value"=>"1"},
    {".parameter"=>"v", ".operator"=>":=", ".value"=>"12"}]],
    [{".module"=>"ABSFL", ".state"=>"Entry"},
    {".module"=>"ABSFL", ".state"=>"CalcSlipRate"},
    [{".parameter"=>"v", ".operator"=>">", ".value"=>"0"}]],
    [{".module"=>"ABSFL", ".state"=>"CalcSlipRate"},
    {".module"=>"ABSFL", ".state"=>"Exit"},
    [{".parameter"=>"v", ".operator"=>"<", ".value"=>40},
    {".parameter"=>"torqueABS", ".operator"=>":=", ".value"=>"0"}]],
    [{".module"=>"ABSFL", ".state"=>"Exit"},
    {".module"=>"ABSFL", ".state"=>"idle"},
    {".empty"=>0}],
    {".empty"=>0}
]

@@ref_name_list_2 = [
    "BBW_ABS_func_component_sliprate_1",
    "BBW_ABS_func_component_sliprate_1",
    "BBW_ABS_func_component_sliprate_1",
    "BBW_ABS_func_component_sliprate_1",
    "BBW_ABS_func_component_sliprate_1"
]

@@comment_list = ["#############################################
# [TestCaseSpecification]
# BBW_ABS_func_component_sliprate_1
# 
# [RequirementSpecification]
# BBW.ABS.func_1 E<>(5*(v-w*R)>v and brake==0)
# 
# [Purpose]
# Slip rate
# 
# [Description]
# Verify if the slip rate is larger than 0.2, the brake torque should be equal to zero
# 
# [Type]
# Functionality
# 
# [Level]
# Structural component
# 
# [ActionEvent]
# A1 Send in a signal such that v is larger than 0 and slip rate is larger than 0.2.
# E1 The module should goes into CalSlipRate state.
# E2 The brake torque should be set to zero.
# E3 The module should goes into Exit state.
# E4 A signal is sent from the module to the test scripts.
# 
# [PassCriteria]
# PASS if parameter values in the return signal are the same as the expected values.
# 
# [EnvironmentRequirement]
# Perform the test using signal communication on Linux.
# 
# [Comment]
# N/A
# 
# 
#############################################
"]

@@ref_parsed_string="[SHORTNAME=BBW_ABS_func_component_sliprate_1]\nState:(ABSFL.idle)\nABSFL.w=0 ABSFL.wheelABS=0\ ABSFL.torqueABS=-1 ABSFL.v=0 ABSFL.R=1 \nTransitions: ABSFL.idle->ABSFL.Entry { w:= 8, wheelABS:= 1, v:= 12}\nState:(ABSFL.Entry)\nABSFL.w=8 ABSFL.wheelABS=1 ABSFL.torqueABS=-1 ABSFL.v=12 ABSFL.R=1 \nTransitions:\nABSFL.Entry->ABSFL.CalcSlipRate { v > 0}\nState:(ABSFL.CalcSlipRate)\nABSFL.w=8 ABSFL.wheelABS=1 ABSFL.torqueABS=0 ABSFL.v=12 ABSFL.R=1 \nTransitions: ABSFL.CalcSlipRate->ABSFL.Exit { v < 5 * (v - w * R / 2), torqueABS:= 0 }\nState: (ABSFL.Exit)\nABSFL.w=8 ABSFL.wheelABS=1 ABSFL.torqueABS=0 ABSFL.v=12 ABSFL.R=1 \nTransitions: ABSFL.Exit->ABSFL.idle { }\nState:(ABSFL.idle)\nABSFL.w=8 ABSFL.wheelABS=1 ABSFL.torqueABS=0 ABSFL.v=12 ABSFL.R=1 \n"

@@ref_option_output= "@@options.outfile= 
test.output
@@options.help= 
false
@@options.verbose= 
true
@@options.debug= 
false
"

@@ref_help = "
Syntax:

   ruby test/tc_testuser.rb [<options>] <files> ...

Description:
   Abstract test case parser for Python.

Options:
   -o <outfile>
           Name of output file. If no extension is given, the 
           generated test case will be named \"testcase.py\"

   -h      Prints this help text.

   -v      Verbose mode.

   -d      Debug mode. When this option is set, a zip file named 
           debug_files.zip will be created, containing input files
           and intermediate files generated during the parsing process.
           
"

@@ref_help_linx4py = "
Syntax:

   ruby test/tc_linx4pyuser.rb [<options>] <files> ...

Description:
   Abstract test case parser for Python.

Options:
   -o <outfile>
           Name of output file. If no extension is given, the 
           generated test case will be named \"testcase.py\"

   -h      Prints this help text.

   -v      Verbose mode.

   -d      Debug mode. When this option is set, a zip file named 
           debug_files.zip will be created, containing input files
           and intermediate files generated during the parsing process.
           
"

class GetRef
   def getTCRef(index)	
      case index
      when 0 
          return @@ref_state_list_0, @@ref_input_list_0, @@ref_transitions_list_0, @@ref_name_list_0
      when 1 
          return @@ref_state_list_1, @@ref_input_list_1, @@ref_transitions_list_1, @@ref_name_list_1
      when 2 
          return @@ref_state_list_2, @@ref_input_list_2, @@ref_transitions_list_2, @@ref_name_list_2
      end
   end   
   def getCommentListRef()	
      return @@comment_list
   end
   def getParsedStringRef()	
      str = ""
      str << @@ref_parsed_string
      return str
   end
   def getOptionsRef()
      return @@ref_option_output
   end
   def getHelpRef()
      return @@ref_help
   end
   def getHelpRefLinx4Py()
      return @@ref_help_linx4py
   end
end
