# testcaseback.rb - Test case parser backend for Python

# Configuration of testing modules
@@configuration = {
	".input" => { 
			".module" => ["ABSFL"],
			".signal" => [
								["ABSFL_w",
								 "ABSFL_v",
								 "ABSFL_wheelABS",
								 "ABSFL_R"]
							]
	},
	".output" => { 
			".module" => ["ABSFL"],
			".signal" => [
									["ABSFL_torqueABS"]
							]
	},
	".testing_module" => [ # in the order of state change
		"ABSFL"
	] 
}

# State info used for comparing state
@@state = {
	"GlobalBrakeController" => {
					"idle" => -1,
					"Entry" => 0,
					"Reaction" => 1
				},
				
	"ABSFL" => {
					"idle" => -1,
					"Entry" => 0,
					"CalcSlipRate" => 1,
					"Exit" => 2
				}
}

class TestCaseBack

  # Extract the interesting test cases and remove unnecessary states
  def locate_valid_test_cases(state_list, input_list, transitions_list, name_list)
  	 
  	 # Declare three returning arrays
    return_transitions_list = []
    return_state_list = []
    return_input_list = []
    return_name_list = []
    
    start_index = -1
    flag = 0
    exit_count = 0;
    
    # Iterate on the transition list and find the beginnings and endings of tests
    # Push the state between the beginning and ending trunk to the arrays
    i = 0
    module_name = ""
     
    while (i < transitions_list.length)
    	a = transitions_list[i]
    	if (a.kind_of?(Array))
    	 	if @@configuration[".input"][".module"].include?(a[0][".module"]) \
		 		and a[0][".state"] == "idle" and flag == 0
		 		module_name = a[0][".module"]
		 	end
		 	if @@configuration[".testing_module"].include?(a[0][".module"]) \
		 		and a[0][".state"] == "idle" and flag == 0
		 		flag = 1
		 		start_index = i
		 	end
		elsif @@configuration[".output"][".module"].include?(module_name) \
    		and a.has_key?(".empty")
    		
    		exit_count += 1
    		module_name = ""
    		
    		if exit_count >= @@configuration[".output"][".module"].length
    			return_transitions_list.push( transitions_list[start_index..i-1])
    			return_state_list.push(state_list[start_index..i])
    			return_input_list.push(input_list[start_index..i])
    			return_name_list.push(name_list[start_index])
    			
    			flag = 0
    			exit_count = 0
    		end
    		 		
   	end

   	i += 1
    end   

    # Clean the list of states
	 test_index = 0
    while (test_index < return_transitions_list.length)
    	current_test = return_transitions_list[test_index]
    	i = 0
    	del_list = []
    	
    	# Locate any state that is not done by any of the test targets
    	while (i < current_test.length)
    		if  @@configuration[".testing_module"].include?(current_test[i][0][".module"]) \
    			or @@configuration[".testing_module"].include?(current_test[i][1][".module"])
    			
    			i +=1
    		else
    			del_list.push(i)
    			i +=1
    		end	

    	end

		# Remove the states located in above loop
    	del_list.reverse_each do |index|
    		return_transitions_list[test_index].delete_at(index)
    		return_state_list[test_index].delete_at(index)
    		return_input_list[test_index].delete_at(index)
    	end
    	
    	test_index += 1
    end
    
    return_tables = return_state_list, return_input_list, return_transitions_list, return_name_list
    return_tables
    
  end

  # Create types.h
  def generate_types_h()
 
  	 # Create director(ies) as needed
    outfile = @@options.outfile
	  
	 parts = outfile.split('/')
    if parts.length == 1
      directory, test_cases_file = ".", parts[0]
    else
      directory, test_cases_file = parts[0..parts.length-2].join("/"), parts[-1]
    end

    FileUtils.mkdir_p(directory) unless File.directory?(directory)
    ofname = "#{directory}/types.h"
    f = File.open(ofname, "w")
    
    # Write to the file
    begin
    
      f.puts "/*\n"
		f.puts " * File: types.h\n"
		f.puts " *\n"
		f.puts " */\n\n"

		f.puts "#ifndef __TYPES_H__\n"
		f.puts "#define __TYPES_H__\n\n"

		f.puts "#define MAX_STATES  10\n\n"

		f.puts "#ifndef TRUE\n"
		f.puts "# define TRUE     (1U)\n"
		f.puts "#endif\n\n"

		f.puts "#ifndef FALSE\n"
		f.puts "# define FALSE    (0U)\n"
		f.puts "#endif\n\n"

		f.puts "/* Data types */\n"
		f.puts "typedef signed char    S8;\n"
		f.puts "typedef unsigned char  U8;\n"
		f.puts "typedef short          S16;\n"
		f.puts "typedef unsigned short U16;\n"
		f.puts "typedef int            S32;\n"
		f.puts "typedef unsigned int   U32;\n\n"

		f.puts "/* Min and max values for data types */\n"
		f.puts "#define MAX_S8       ((S8)(127))\n"
		f.puts "#define MIN_S8       ((S8)(-128))\n"
		f.puts "#define MAX_U8       ((U8)(255U))\n"
		f.puts "#define MIN_U8       ((U8)(0U))\n"
		f.puts "#define MAX_S16      ((S16)(32767))\n"
		f.puts "#define MIN_S16      ((S16)(-32768))\n"
		f.puts "#define MAX_U16      ((U16)(65535U))\n"
		f.puts "#define MIN_U16      ((U16)(0U))\n"
		f.puts "#define MAX_S32      ((S32)(2147483647))\n"
		f.puts "#define MIN_S32      ((S32)(-2147483647-1))\n"
		f.puts "#define MAX_U32      ((U32)(0xFFFFFFFFU))\n"
		f.puts "#define MIN_U32      ((U32)(0U))\n\n"

		f.puts "#endif  /* __TYPES_H__ */\n"

      f.close
      
    # Error handling of file corruption
    rescue
      f.close
      File.delete(ofname)
      raise
    end
  end

  # Create structure file of a module
  def generate_structure(target, input_list)
 
  	 # Create director(ies) as needed
    outfile = @@options.outfile
	  
	 parts = outfile.split('/')
    if parts.length == 1
      directory, test_cases_file = ".", parts[0]
    else
      directory, test_cases_file = parts[0..parts.length-2].join("/"), parts[-1]
    end

    FileUtils.mkdir_p(directory) unless File.directory?(directory)
    ofname = "#{directory}/signal_#{target.downcase}.h"
    f = File.open(ofname, "w")
    
    # Write to the structure file
    begin
    
		f.puts "#ifndef _SIGNAL_#{target}_H_\n"
		f.puts "#define _SIGNAL_#{target}_H_\n"

		f.puts "#include \"types.h\"\n\n"

		# Define enumeration as the state of the module
		f.puts "typedef enum {\n"
		i = 0
		@@state[target].keys.each do |state|
			f.write "  #{state} = #{@@state[target][state]}" 
			if i < @@state[target].keys.length - 1
				f.puts ",\n"
			end
			i += 1
		end
		f.puts "\n} #{target}State;\n\n"
		
		# Check if the module is an input, if yes, declare the input structure
		i = 0
		target_id = -1
		while i < @@configuration[".input"][".module"].length
			if @@configuration[".input"][".module"][i] == target
				target_id = i
			end
			i += 1
		end
		if (target_id > -1)
			f.puts "typedef struct {\n"
			@@configuration[".input"][".signal"][target_id].each do |input|
				f.puts "  U32 #{input};\n" 
			end
			
			f.puts "} #{target}Input;\n\n"
			
		end 
				
		# Declare the output trace structure
		f.puts "typedef struct {\n"
		input_list.each do |parameter|
			if parameter[".module"] == target
				name = parameter[".parameter"]
				f.puts "  U32 #{name};\n"
			end
		end
		f.puts "  U32 state;\n"
		f.puts "} #{target}StateTrace;\n\n"

		f.puts "#endif\n"
    	f.close
    # Error handling of file corruption
    rescue
      f.close
      File.delete(ofname)
      raise
    end
  end


  # Create signals.sig
  def generate_signals_sig(input_list)
 
  	 # Create director(ies) as needed
    outfile = @@options.outfile
	  
	 parts = outfile.split('/')
    if parts.length == 1
      directory, test_cases_file = ".", parts[0]
    else
      directory, test_cases_file = parts[0..parts.length-2].join("/"), parts[-1]
    end

    FileUtils.mkdir_p(directory) unless File.directory?(directory)
    ofname = "#{directory}/signals.sig"
    f = File.open(ofname, "w")
    i = 13121;
    
    # Write to the signals.sig file
    begin
		f.puts "#ifndef _SIGNALS_SIG_\n"
		f.puts "#define _SIGNALS_SIG_\n\n"

		f.puts "#include <linx.h>\n"
		@@configuration[".testing_module"].each do |target|
			f.puts "#include \"signal_#{target.downcase}.h\"\n"
		end
		
		# Define the input signals
		@@configuration[".input"][".module"].each do |target|
			temp_signal = "/*!- SIGNO(struct #{target.downcase}_input_sig) -!*/"
			f.puts "\n#define #{target}_INPUT_SIG #{i} #{temp_signal}\n" 
			f.puts "struct #{target.downcase}_input_sig {\n"
			f.puts "  LINX_SIGSELECT sig_no;\n"
			f.puts "  #{target}Input input;\n"
			f.puts "};\n\n"
			i += 1
		end

		# Define the trace signals
		@@configuration[".testing_module"].each do |target|
			temp_signal = "/*!- SIGNO(struct #{target.downcase}_output_sig) -!*/"
			f.puts "#define #{target}_OUTPUT_SIG #{i} #{temp_signal}\n" 
			f.puts "struct #{target.downcase}_output_sig {\n"
			f.puts "  LINX_SIGSELECT sig_no;\n"
			f.puts "  U32 num_states;\n"
			f.puts "  #{target}StateTrace states[MAX_STATES];\n"
			f.puts "};\n\n"
			i += 1
		end

		# Define LINX_SIGNAL union
		f.puts "union LINX_SIGNAL {\n"
		f.puts "  LINX_SIGSELECT sig_no;\n"
		@@configuration[".input"][".module"].each do |target|
			f.puts "  struct #{target.downcase}_input_sig #{target.downcase}_input;\n"
		end
		@@configuration[".testing_module"].each do |target|
			f.puts "  struct #{target.downcase}_output_sig #{target.downcase}_output;\n"
		end
		f.puts "};\n\n"

		f.puts "#endif /* _SIGNALS_SIG_ */\n"
    	f.close
    # Error handling of file corruption
    rescue
      f.close
      File.delete(ofname)
      raise
    end
    
    # For each testing modules, generate a header file for the structure
    @@configuration[".testing_module"].each do |target|
    	generate_structure(target, input_list)
    end
  end

  # Create executable Python test cases
  def generate_test_cases(tables, comment_list)

    # Extract the interesting test cases 
    state_list, input_list, transitions_list, name_list = tables
    valid_state_list, valid_input_list, valid_transitions_list, valid_name_list = \
    	locate_valid_test_cases(state_list, input_list, transitions_list, name_list) 

    if valid_state_list.empty?
      raise "No complete test case is found"
    end
    # Create director(ies) as needed
    outfile = @@options.outfile

    parts = outfile.split('/')
    if parts.length == 1
      directory, test_cases_file = ".", parts[0]
    else
      directory, test_cases_file = parts[0..parts.length-2].join("/"), parts[-1]
    end

    FileUtils.mkdir_p(directory) unless File.directory?(directory)
    ofname = "#{directory}/#{test_cases_file}"
    f = File.open(ofname, "w")
    
    # Create the test cases
    begin
      # Create header of the test cases
      f.puts "# #{test_cases_file} - Test cases\n"
      f.puts "# ----------------------------------------------------------------\n"
      f.puts "# WARNING: Do not modify this file. It is automatically generated\n"
      f.puts "#          from abstract test cases. Any modification will be lost\n"
      f.puts "#          the next time the file is generated.\n"
      f.puts "\n"
      f.puts "\"\"\"\n"
      f.puts "Test cases generated from:\n"
      @@options.files.each {|name| f.puts "    #{name}\n"}
      f.puts "Generated by:\n"
      f.puts "    #{$0}\n"
      f.puts "\"\"\"\n\n"
      f.puts "import sys\n"
      f.puts "import ogre\n"
      f.puts "import signals\n"
      f.puts "import unittest\n"
	   f.puts "import xmlrunner\n\n"
	   
      # Create Linx declaration block      
      f.puts "if (len(sys.argv) > 1):\n"
      f.puts "\tLINK = sys.argv[1] + \"/\"\n"
      f.puts "else:\n"
      f.puts "\tLINK = \"\"\n\n"
      
      valid_state_list[0][0].each do |a|
      	if @@configuration[".testing_module"].include?(a[".module"])
      		f.puts "#{a[".module"]} = LINK + \"#{a[".module"]}Linx\"\n"
			end
      end
		f.puts "TESTSERVER = \"TESTSERVER\"\n\n"
		f.puts "class Test(unittest.TestCase):\n\n"

		# Create setUp block of the tests
		f.puts "\tdef setUp(self):\n"
		f.puts "\t\tself.linx = ogre.create(\"linx\", TESTSERVER)\n\n"
		
		valid_state_list[0][0].each do |a|
			if @@configuration[".testing_module"].include?(a[".module"])
      		f.puts "\t\t# Hunt for #{a[".module"]} model\n"
      		f.puts "\t\tself.linx.hunt(#{a[".module"]})\n"
				f.puts "\t\tself.pid_#{a[".module"]} = self.linx.receive().sender()\n\n"
			end
      end

		# Create tearDown block of the tests
		f.puts "\tdef tearDown(self):\n"
		f.puts "\t\tpass\n\n"

		# Create a test for each test case 
		testcase_number = 0
		while (testcase_number < valid_state_list.length)
			if comment_list.length > 0
				temp = comment_list[testcase_number]
				loop do
					next if temp.sub!("\n#", "\n\t#")  # Suppress spaces
					break
				end
			end
			
			f.puts "\t#{temp}"
			f.puts "\tdef test#{testcase_number}_#{valid_name_list[testcase_number]}(self):\n"
			 
			# For each modules specified in input of @@configuration 
			# Look for the input values for the input and send the input signals
			i = 0
			while i < valid_transitions_list[testcase_number].length
				if @@configuration[".input"][".module"].include?( \
					valid_transitions_list[testcase_number][i][0][".module"]) and \
					valid_transitions_list[testcase_number][i][0][".state"] == "Entry"

					index = @@configuration[".input"][".module"].index( \
					valid_transitions_list[testcase_number][i][0][".module"])

					target = @@configuration[".input"][".module"][index]
					signal_list = @@configuration[".input"][".signal"][index]
					
					f.puts "\t\t# Sending input signal to #{target}\n"
					f.puts "\t\tsig_send_#{target} = signals.#{target}_INPUT_SIG()\n"
					
					signal_list.each do |signal|
						valid_input_list[testcase_number][i].each do |value|
							tmp_concate = value[".module"] + "_" + value[".parameter"]
							if (tmp_concate == signal)
								f.puts "\t\tsig_send_#{target}.input.#{signal} = #{value[".value"]}\n"
							end
						end
					end 
					
					f.puts "\t\tself.linx.send(sig_send_#{target}, self.pid_#{target})\n\n"
				
				end
				i += 1
			end	
			
			# Receive all the signals from the targets listed in @@configuration
			f.puts "\t\t# Receive signals from test targets\n"
			@@configuration[".testing_module"].each do |target|
				temp_signo = "[signals.#{target}_OUTPUT_SIG.SIGNO]"
				f.puts "\t\tsig_recv_#{target} = self.linx.receive(#{temp_signo})\n"
			end

			# Follow the order in @@configuration and compare the results with traces
			index_counter = 0
			@@configuration[".testing_module"].each do |target|
				state_change = []
				param_list = []
				logical_expression = []
				have_logical = false

				f.puts "\n\t\t# Testing of #{target}\n"
				
				# Get the list of parameter names that need comparison
				valid_input_list[0][0].each do |input|
					if input[".module"] == target
						param_list << input[".parameter"]
					end
				end				
				
				# Get the expected value from valid_input_list and expected state from 
				# valid_transitions_list
				param_value = []
				while (index_counter < valid_transitions_list[testcase_number].length \
							and valid_transitions_list[testcase_number][index_counter][0][".module"] == target)
					
					# Get the state
					state_change.push( \
							@@state[target]["#{valid_transitions_list[testcase_number][index_counter][1][".state"]}"]
						)
					
					# Get the logical expression to be checked	
					if valid_transitions_list[testcase_number][index_counter][2].kind_of?(Array)
						have_logical = true
					end
					logical_expression.push( 
							valid_transitions_list[testcase_number][index_counter][2])
	
	
					# Get the input value and store in param_value
					param_count = 0
					while param_count < param_list.length do
	
						j = 0
						while j < valid_input_list[testcase_number][index_counter].length
							if (valid_input_list[testcase_number][index_counter][j][".parameter"] == param_list[param_count]) \
								and valid_input_list[testcase_number][index_counter][j][".module"] == target
								param_value.push(valid_input_list[testcase_number][index_counter][j][".value"])
							end 
							j += 1
						end 

						param_count += 1
					end
					index_counter += 1
				end 
				
				# For each paramter, extract the value from param_value 
				param_count = 0
				while param_count < param_list.length
					value_list = []
					value_count = param_list.length # Skip the first element
					while value_count < param_value.length do
						if value_count % param_list.length == param_count
							value_list.push(param_value[value_count])
						end
						value_count += 1
					end
					
					# Create expected results in test cases
					if value_list.length > 1
						f.write "\t\t#{target}_#{param_list[param_count]} = [#{value_list[1]}"
						i = 2
						while i < value_list.length
							f.write ", #{value_list[i]}"
							i += 1
						end
						f.write "]\n"	
					end	
					param_count += 1
				end
		
				# Create expected states in test cases
				if state_change.length > 1
					f.write "\t\t#{target}_state = [#{state_change[1]}"
					i = 2
					while i < state_change.length
						if state_change[i] != @@state[target]["idle"]
							f.write ", #{state_change[i]}"
						end
						i += 1
					end
					f.write "]\n"	
				end	
				
				# Compare the received data with expected values
				f.puts "\t\tfor i in range(sig_recv_#{target}.num_states):\n"
				f.puts "\t\t\tprint \"Transition %d:\" %(i+1)"
				f.puts "\t\t\tself.assertEqual(sig_recv_#{target}.states[i].state, #{target}_state[i])\n"
				f.puts "\t\t\tprint \"\tstate = %d\" %sig_recv_#{target}.states[i].state"
				param_list.each do |variable|
					f.puts "\t\t\tself.assertEqual(sig_recv_#{target}.states[i].#{variable}, #{target}_#{variable}[i])\n"
					f.puts "\t\t\tprint \"\t#{variable} = %d\" %sig_recv_#{target}.states[i].#{variable}"
				end

				# Generate logical comparison
				if have_logical
					f.puts "\n\t\t# Check if the logical requirements are fulfilled"
					i = 1
					while i < logical_expression.length - 1
						if logical_expression[i].kind_of?(Array)
							logical_expression[i].each do |element|
								operator = element[".operator"]

								if operator.eql? ":="
									operator = "=="
								end
								
								temp_param = "#{element[".parameter"]}"
								temp_rest = "#{operator} #{element[".value"]}"
								temp_signal = "sig_recv_#{target}.states[#{i}].#{element[".parameter"]}"
								f.puts "\t\tprint \"check if #{temp_param} #{temp_rest} at tranistion #{i}\"\n"
								f.puts "\t\tself.assertTrue(#{temp_signal} #{temp_rest})\n"
								
							end
						end
						i += 1
					end 
				end				
					
			end
			f.puts "\t\tprint \n\n"
			testcase_number += 1
		end 
		
		# Create the XML generation block
		f.puts "if __name__ == '__main__':"
		f.puts "\tdel sys.argv[1:]"
		f.puts "\tunittest.main(testRunner=xmlrunner.XMLTestRunner(output=\"unittests\"))\n"
      f.puts "\n# End of file\n"
      f.close
      
    # Error handling of file corruption
    rescue
      f.close
      File.delete(ofname)
      raise
    end
	  
	  
  end	  

end
