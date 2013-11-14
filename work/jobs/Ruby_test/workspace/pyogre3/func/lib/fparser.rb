# fparser.rb - Function parser backend generating C function files

#
# Generate C function files
#
class Fparser

   # Return a string containing the type of a parsed variable
   def type(elem)
   # --------------------------------------------------------------------------
   # input:
   #     elem - A nested hash containing parameter definition
   # output
   #     A string containing the parameter type (e.g. const volatile int*)
   # --------------------------------------------------------------------------
   
      # ----------
      # Ellipsis (not handled by the function parser)
      if elem['.type'] == "ellipsis"
         # Special type...                Fixme!
         #return "OgreDotDotDot"
         return "void"
      
      # ----------
      # Pointer
      elsif elem['.type'] == "pointer"
         # Find what the pointer points at (recursive)
         base = type(elem['.subtype'])

         # Add type qualifiers to the pointer if any
         if elem.has_key?('.type_qualifier')
            addon = " * " + elem['.type_qualifier']
         else
            addon = " *"
         end
         
         # Place pointer correctly if several levels of pointers.
         # Especially important if type qualifiers are present.
         if base =~ /(^.*)\s(\*.*)/
            return $1 + addon + $2
         else
            return base + addon
         end
      
      # ----------
      # Array
      elsif elem['.type'] == "array"
         # Find what the array type (recursive)
         base = type(elem['.subtype'])
         # Find size of array
         addon = "[" + elem['.array_size'].to_s + "]"
         
         # Check if it is an array of function pointers
         if base =~ /(.*ReplaceHere\)\(.*\)\**)([\[\]\d]+$)/
            return $1 + addon + $2
         
         # Ensure that the array is written correctly if it has several dimensions
         elsif base =~ /^([^\[]*)([^\)]*$)/
            return $1 + addon + $2
         
         # Only one dimension
         else
            return base + addon
         end
      
      # ----------
      # Function (not type defined)
      elsif elem['.type'] == "function" && !elem.has_key?('.type_or_id_name')
         # Parse input parameters of the function
         input = extract_input(elem['.input'], 'arg')
         
         # Add the type returned from the function to a new string
         func_str = type(elem['.subtype'])
         # Add a replaceable parameter name
         func_str << " (ReplaceHere)("
         # Add input parameters
         for i in (0..input.length - 1)
            func_str << input[i]
            if i < input.length - 1
               func_str << ", "
            end
         end
         # End definition
         func_str << ")"

         return func_str 
      
      # ----------
      # Other type (not ellipsis, pointer, array or function)
      else
         # String used to build up the type
         type_string = ""
        
         # Struct, Enum or Union
         if elem['.type'] == "struct" ||  elem['.type'] == "enum" ||  elem['.type'] == "union"

            # Check if a type or ID tag is defined
            if elem.has_key?('.type_or_id_name')
               # Add struct/enum/union if the name isn't defined as a type
               elem['.type_or_id_name'] =~ /\((.+)\): \w+/
               if $1 != "Type"
                  type_string = elem['.type'] + " " + type_string
               end
            # Add struct/enum/union if no type or ID tag is defined
            else
               type_string = elem['.type'] + " " + type_string
            end
         end

         # Add type qualifyer(s) if existing (const, volatile)
         if elem.has_key?('.type_qualifier')
            type_string = elem['.type_qualifier'] + " " + type_string
         end

         # Add the typename...
         if elem.has_key?('.type_or_id_name')
            elem['.type_or_id_name'] =~ /\(.+\): (\w+)/
            type_string <<  $1
         
         # ...or add signed/unsigned + type...
         elsif elem.has_key?('.signed')
            type_string << elem['.signed'] + " " + elem['.type']
         
         # ...or add only type
         else
            type_string << elem['.type']
         end
         
         return type_string
      end
   end

   # Creates an array of string describing input parameters to a parsed function
   def extract_input(input_array, parameter_name)
   # --------------------------------------------------------------------------
   # input:
   #     input_array    - An array of hashes, describing the input parameters
   #     parameter_name - The base name for input parameters
   # output:
   #     An array of function input parameters as strings
   # --------------------------------------------------------------------------
   
      # Create an empty array
      output = Array.new
      
      # Parameter number (start value)
      input_nr = 0
      
      # Go through all elements in the input array
      input_array.each do |input|
         # Get parameter type
         type_str = type(input)
         
         # Don't add 'void' parameter to array
         if type_str != "void"

            # Check if input parameter is a function pointer
            # Split the string and remove 'ReplaceHere'
            if type_str =~ /(^.*)ReplaceHere(.*$)/
               start_string = $1
               end_string = $2

               # Array of function pointers
               if end_string =~ /(.*)(\*+)([\[\]\d]*$)/
                  end_string = $3 + $1
                  start_string << $2 
               end
               
               # Push parameter to output array
               output.push(start_string + parameter_name + input_nr.to_s + end_string)
            else
               array_str = ""
               # Array - Split string before first '['
               if type_str =~ /^([^\[]*)(.*\]$)/
                  type_str = $1
                  array_str = $2
               end

               # Push parameter to output array
               output.push(type_str + " " + parameter_name + input_nr.to_s + array_str)
            end
            
            # Increase parameter number
            input_nr = input_nr.next
         end
      end
      
      # Return the array containing information about input parameters
      return output
   end
   
   # Parse the table of parsed function prototypes
   def parse_symbol_table(symbol_table, parameter_name)
   # --------------------------------------------------------------------------
   # input:
   #     symbol_table   - A table containg all parsed function prototypes
   #     parameter_name - The base name for input parameters
   # output:
   #     An array of hashes containing information about each function
   # --------------------------------------------------------------------------
      
      # Create empty output array
      output = Array.new
      
      # Go through each element in the symbol table
      symbol_table['table_data'].each do |elem|
         
         # Process symbols that are functions
         if elem[1]['.type'] == "function"
            
            # Create a new hash for the current function
            h = Hash.new
            
            # Execute signal name
            h['sig_exec']     = "OGRE_" + elem[0].upcase + "_EXECUTE"
            # Execute signal struct name
            h['struct_exec']  = "Ogre" + elem[0].capitalize + "Execute"
            # Reply signal name
            h['sig_reply']    = "OGRE_" + elem[0].upcase + "_REPLY"
            # Reply signal struct name
            h['struct_reply'] = "Ogre" + elem[0].capitalize + "Reply"
            # Function name
            h['function']     = elem[0]
            # Array of input parameters (e.g. 'const int *param0')
            h['input']        = extract_input(elem[1]['.input'], parameter_name)
            # Output parameter (e.g. 'volatile char*')
            h['output']       = type(elem[1]['.subtype'])

            # Push hash to output array
            output.push h
         end
      end
      
      # Return the array containing information about all functions
      return output
   end
   
   # Prints utility functions to a file
   def include_utility_functions(file)
   # --------------------------------------------------------------------------
   # input:
   #     file - A file descriptor to the file where the functions shall be written
   # --------------------------------------------------------------------------
      
      # ----------
      # Print redirect function
      file.print "/* Redirects output written to stdout to a file */\n" +
         "static int std_redirect(FILE *source, const char *file_name)\n" +
         "{\n" +
         "   int oldstd;\n" +
         "   /* Flush source stream */\n" +
         "   fflush(source);\n" +
         "   /* Duplicate file descriptor */\n" +
         "   oldstd = dup(fileno(source));\n" +
         "   /* Create a new file, reusing an open stream */\n" +
         "   freopen(file_name, \"w\", source);\n" +
         "   return oldstd;\n" +
         "}\n\n"
      
      # ----------
      # Print restore function
      file.print "/* Restores stdout to the state it had before redirection */\n" +
         "static void std_restore(FILE *dest, int oldstd)\n" +
         "{\n" +
         "   /* Flush destination */\n" +
         "   fflush(dest);\n" +
         "   /* Restore redirection */\n" +
         "   dup2(oldstd, fileno(dest));\n" +
         "   /* Close the duplicated file pointer */\n" +
         "   close(oldstd);\n" +
         "   return;\n" +
         "}\n\n"
      
      # ----------
      # Print function that reads file data and send it to the host
      file.print "/* Send the content of file_name to process with PID=pid */\n" +
         "static void send_data(const char *file_name, PROCESS pid)\n" +
         "{\n" +
         "   /* File pointer */\n" +
         "   FILE *file;\n" +
         "   /* Initiate character count variable */\n" +
         "   int count = 0;\n" +
         "   /* The current character from the file */\n" +
         "   int ch;\n" +
         "   /* Signal pointer */\n" +
         "   union SIGNAL *sig;\n\n" +
         "   /* Open the file which content shall be sent */\n" +
         "   file = fopen(file_name, \"r\");\n" +
         "   /* Count the number of chars in the file */\n" +
         "   while ((ch = fgetc(file)) != EOF) { ++count; }\n" +
         "   /* 'Rewind' the file */\n" +
         "   rewind(file);\n\n" +
         "   /* Allocate a big enough reply signal buffer */\n" +
         "   sig = alloc(sizeof(struct OgreStdoutData) + sizeof(char) * count, OGRE_STDOUT_DATA);\n" +
         "   /* Copy the file content into the reply signal buffer */\n" +
         "   fread(sig->OgreStdoutData.data, sizeof(char), count + 1, file);\n" +
         "   /* Set the dynamic array size value */\n" +
         "   sig->OgreStdoutData.size = count + 1;\n" +
         "   /* Print the string to the stdout on the target */\n" +
         "   /* The stdout should already have been restored */\n" +
         "   printf(\"%s\", sig->OgreStdoutData.data);\n" +
         "   /* Send the reply signal */\n" +
         "   send(&sig, pid);\n\n" +
         "   /* Close the file */\n" +
         "   fclose(file);\n" +
         "   /* Remove the temporary file */\n" +
         "   remove(file_name);\n" +
         "   /* Flush stdout */\n" +
         "   fflush(stdout);\n" +
         "   return;\n" +
         "}\n\n"
      
      # ----------
      # Print function that reads a string from a pointer and returns the string
      file.print "/* Reads a string and sends the string in a signal */\n" +
        "static void read_string(union SIGNAL *sig_in)\n" + 
        "{\n" + 
        "   /* Signal pointer */\n" + 
        "   union SIGNAL *sig_out;\n" + 
        "   /* Allocate a signal buffer large enough to hold the requested string */\n" + 
        "   sig_out = alloc(sizeof(struct OgreStringReadReply) + strlen(sig_in->OgreStringReadRequest.pointer) + 1, OGRE_STRING_READ_REPLY);\n" + 
        "   /* Copy the requested string to the signal buffer */\n" + 
        "   strcpy(sig_out->OgreStringReadReply.str, sig_in->OgreStringReadRequest.pointer);\n" + 
        "   /* Set the dynamic array size value */\n" + 
        "   sig_out->OgreStringReadReply.size = strlen(sig_in->OgreStringReadRequest.pointer) + 1;\n" + 
        "   /* Send the signal */\n" + 
        "   send(&sig_out, sender(&sig_in));\n" + 
        "   /* Free the incoming signal buffer */\n" + 
        "   free_buf(&sig_in);\n" + 
        "   return;\n" + 
        "}\n\n"
      
      # ----------
      # Print function that stores a string in memory and returns a pointer
      file.print "/* Writes a string to memory and sends a pointer to it in a signal */\n" +
         "static void write_string(union SIGNAL *sig_in)\n" +
         "{\n" +
         "   /* Signal pointer */\n" +
         "   union SIGNAL *sig_out;\n" +
         "   /* Allocate a reply signal buffer */\n" +
         "   sig_out = alloc(sizeof(struct OgreStringWriteReply), OGRE_STRING_WRITE_REPLY);\n" +
         "   /* Allocate a memory area large enough to hold the requested string */\n" +
         "   sig_out->OgreStringWriteReply.pointer = (char *) malloc(sig_in->OgreStringWriteRequest.size);\n" +
         "   /* Copy the requested string to the allocated memory area */\n" +
         "   strcpy(sig_out->OgreStringWriteReply.pointer, sig_in->OgreStringWriteRequest.str);\n" +
         "   /* Send the reply signal */\n" +
         "   send(&sig_out, sender(&sig_in));\n" +
         "   /* Free the incoming signal buffer */\n" +
         "   free_buf(&sig_in);\n" +
         "   return;\n" +
         "}\n\n"
      
      # ----------
      # 
      file.print "/* Test function used to verify stdout catch */\n" +
         "int print_test_function(void)\n" +
         "{\n" +
         "   printf(\"first line\\n\");\n" +
         "   printf(\"This is print_test_function using printf() to write to stdout!\\n\");\n" +
         "   printf(\"Some printout from the function.\\n\");\n" +
         "   printf(\"last \");\n" +
         "   printf(\"line\\n\");\n" +
         "   fflush(stdout);\n" +
         "   return 0;\n" +
         "}\n\n"
      
      return
   end
  
   # Prints utility signals to a file
   def include_utility_signals(file, offset)
   # --------------------------------------------------------------------------
   # input:
   #     file   - A file descriptor to the file where the functions shall be written
   #     offset - The offset of the first signlas
   # output:
   #     The offset of the last signal + 1
   # --------------------------------------------------------------------------
     
      # ----------
      # Signal used to return stdout catches
      file.print "#define OGRE_STDOUT_DATA " + (@@options.sigbase + offset).to_s + " /* !-SIGNO(struct OgreStdoutData)-! */\n"
      file.print "struct OgreStdoutData {\n"
      file.print "   SIGSELECT sigNo;\n"
      file.print "   unsigned int size;\n"
      file.print "   char data[1];\n"
      file.print "};\n"

      # Add information about the dymnaic array (needed by the signal parser)
      file.print "/* !-ARRAY_SIZE(OgreStdoutData.data, size)-! */\n\n"

      # Increase the signal number offset
      offset = offset.next
      
      # ----------
      # Signal used to read a string from a pointer
      file.print "#define OGRE_STRING_READ_REQUEST " + (@@options.sigbase + offset).to_s + " /* !-SIGNO(struct OgreStringReadRequest)-! */\n"
      file.print "struct OgreStringReadRequest {\n"
      file.print "   SIGSELECT sigNo;\n"
      file.print "   char *pointer;\n"
      file.print "};\n\n"

      # Increase the signal number offset
      offset = offset.next

      # ----------
      # Signal used to read a string from a pointer
      file.print "#define OGRE_STRING_READ_REPLY " + (@@options.sigbase + offset).to_s + " /* !-SIGNO(struct OgreStringReadReply)-! */\n"
      file.print "struct OgreStringReadReply {\n"
      file.print "   SIGSELECT sigNo;\n"
      file.print "   unsigned int size;\n"
      file.print "   char str[1];\n"
      file.print "};\n"

      # Add information about the dymnaic array (needed by the signal parser)
      file.print "/* !-ARRAY_SIZE(OgreStringReadReply.str, size)-! */\n\n"
      
      # Increase the signal number offset
      offset = offset.next

      # ----------
      # Signal used to write a string to the memory and return a pointer
      file.print "#define OGRE_STRING_WRITE_REQUEST " + (@@options.sigbase + offset).to_s + " /* !-SIGNO(struct OgreStringWriteRequest)-! */\n"
      file.print "struct OgreStringWriteRequest {\n"
      file.print "   SIGSELECT sigNo;\n"
      file.print "   unsigned int size;\n"
      file.print "   char str[1];\n"
      file.print "};\n"

      # Add information about the dymnaic array (needed by the signal parser)
      file.print "/* !-ARRAY_SIZE(OgreStringWriteRequest.str, size)-! */\n\n"
      
      # Increase the signal number offset
      offset = offset.next

      # ----------
      # Signal used to write a string to the memory and return a pointer
      file.print "#define OGRE_STRING_WRITE_REPLY " + (@@options.sigbase + offset).to_s + " /* !-SIGNO(struct OgreStringWriteReply)-! */\n"
      file.print "struct OgreStringWriteReply {\n"
      file.print "   SIGSELECT sigNo;\n"
      file.print "   char *pointer;\n"
      file.print "};\n"
      file.print "\n"
      
      # Increase the signal number offset
      offset = offset.next
      
      # ----------
      # Return the signal number offset
      return offset
   end

   # Generate two files - .c and .sig
   def generate_files(symbol_table, include_table)
   # --------------------------------------------------------------------------
   # input:
   #     symbol_table  - A table containg all parsed function prototypes
   #     include_table - A table containg all lines of C code that need to be included (e.g. #include "file.h")
   # output:
   #     .c-file containing an OSE process
   #     .sig-file containing signal definitions
   # --------------------------------------------------------------------------
   
      # Parameter base name
      parameter_name = "param"
      
      # Parse the symbol table to get function data
      data = parse_symbol_table(symbol_table, parameter_name)
      
      # Signal number offset
      sig_nr = 0
      
      # Output file names
      sig_file = @@options.outfile + ".sig"
      c_file   = @@options.outfile + ".c"
      
      # Output file names without path
      c_file_short = c_file
      sig_file_short = sig_file
      
      if c_file =~ /([^\/]*.c$)/
         c_file_short = $1
      end
      if sig_file =~ /([^\/]*.sig$)/
         sig_file_short = $1
      end
      
      #########################################################################
      # Create C file

      # Open/create the file
      f_c = File.open(c_file, "w")

      # ----------
      # Print file header to the C file
      f_c.print "/* " + c_file_short + " - C process */\n"
      f_c.print "/*-------------------------------------------------------------------*/\n"
      f_c.print "/* WARNING: Do not modify this file. It is automaticaly generated.   */\n"
      f_c.print "/*          All modifications will be lost when the generator is run.*/\n"  
      f_c.print "\n"
      
      # ----------
      # Includes needed by the utility function etc.
      f_c.print "#include \"stdio.h\"\n"       # fopen(), fclose() ...
      f_c.print "#include \"unistd.h\"\n"      # dup(), dup2() ...
      f_c.print "#include \"string.h\"\n"      # strcpy()
      f_c.print "#include \"stdlib.h\"\n"      # malloc()
      f_c.print "#include \"ose.h\"\n"         # SIGSELECT etc.
      f_c.print "\n"
      # Include the signal file
      f_c.print "#include \"" + sig_file_short + "\"\n"

      # Print lines not already written from 'include_table' in the C file
      include_table.each do |include_item|
         if include_item =~ /^#include [<"](.*)[>"]/
            if $1 != "stdio.h" && $1 != "unistd.h" && $1 != "string.h" && $1 != "stdlib.h" && $1 != "ose.h"
               f_c.print include_item + "\n"
            end
         end
      end

      # ----------
      # Print the union SIGNAL statement in the C file
      f_c.print "\n"
      f_c.print "union SIGNAL {\n"
      f_c.print "   SIGSELECT sigNo;\n\n"
      
      # Structs used by utility signals
      f_c.print "   /* Utility signal structs */\n"
      f_c.print "   struct OgreStdoutData OgreStdoutData;\n"
      f_c.print "   struct OgreStringReadRequest OgreStringReadRequest;\n"
      f_c.print "   struct OgreStringReadReply OgreStringReadReply;\n"
      f_c.print "   struct OgreStringWriteRequest OgreStringWriteRequest;\n"
      f_c.print "   struct OgreStringWriteReply OgreStringWriteReply;\n\n"
      
      # Structs used by function execute/reply signals
      f_c.print "   /* Function execute/reply signal structs */\n"
      data.each do |h|
         f_c.print "   struct " + h['struct_exec']  + " " + h['struct_exec']  + ";\n"
         f_c.print "   struct " + h['struct_reply'] + " " + h['struct_reply'] + ";\n"
      end
      
      # End union SIGNAL statement
      f_c.print "};\n\n"
      
      # ----------
      # Include utility functions
      include_utility_functions(f_c)
     
      # ----------
      # Print the process in the C file
      f_c.print "OS_PROCESS(ogre_proc_exec)\n"
      f_c.print "{\n"
      f_c.print "   /* Signal variables */\n"
      f_c.print "   SIGSELECT any[] = {0};\n"
      f_c.print "   union SIGNAL *sig_in;\n"
      f_c.print "   union SIGNAL *sig_out;\n"
      f_c.print "   /* Storage for the 'original' stdout descriptor */\n"
      f_c.print "   int stdout_redirect;\n"
      f_c.print "   /* Filename of temporary storage of stdout during redirection */\n"
      f_c.print "   char stdout_filename[] = \"/ram/stdout_temp\";\n\n"
      f_c.print "   /* Infinite loop */\n"
      f_c.print "   while (1)\n   {\n"
      f_c.print "      /* Receive any signal */\n"
      f_c.print "      sig_in = receive(any);\n"
      f_c.print "      /* Do something depending on the signal number */\n"
      f_c.print "      switch (sig_in->sigNo)\n      {\n\n"
      
      # ----------
      # Signals used to read or write a string from a pointer
      f_c.print "      /* Utility signals */\n\n"
      f_c.print "      case OGRE_STRING_READ_REQUEST:\n"
      f_c.print "         read_string(sig_in);\n"
      f_c.print "         break;\n"

      f_c.print "      case OGRE_STRING_WRITE_REQUEST:\n"
      f_c.print "         write_string(sig_in);\n"
      f_c.print "         break;\n\n"
      
      # ----------
      # Print one case for each function parsed from the symbol table
      f_c.print "      /* Function execution signals */\n\n"
      f_c.print "      /* The following cases follow the following pattern: */\n"
      f_c.print "      /* - Redirect stdout if 'catch_stdout' in the incoming signal is set to 1 */\n"
      f_c.print "      /* - Allocate a reply signal */\n"
      f_c.print "      /* - Execute the function and save the return value if any */\n"
      f_c.print "      /* - Restore stdout and the the captured data */\n"
      f_c.print "      /* - Send the reply signal */\n"
      f_c.print "      /* - Free the incoming signal buffer */\n\n"
      
      data.each do |h|
         # Print 'case SIGNAL_NAME:'
         f_c.print "      case " + h['sig_exec'] + ":\n"
         
         # Redirect stdout if catch_stdout == TRUE
         f_c.print "         if (sig_in->" + h['struct_exec'] + ".catch_stdout)\n         {\n"
         f_c.print "            stdout_redirect = std_redirect(stdout, stdout_filename);\n"
         f_c.print "         }\n"
         
         # Allocate reply signal
         f_c.print "         sig_out = alloc(sizeof(struct " + h['struct_reply'] + "), " + h['sig_reply'] + ");\n"

         # Check if the function will return a value
         if h['output'] != "void"
            # Print function call and save the return value in the reply signal
            f_c.print "         sig_out->" + h['struct_reply'] + ".return_value = " + h['function'] + "("
         else
            # Print function call - no return value to save
            f_c.print "         " + h['function'] + "("
         end

         # Print input parameters to the function call
         for i in (0..h['input'].length - 1)
            f_c.print "sig_in->" + h['struct_exec'] + "." + parameter_name + i.to_s
            if i < h['input'].length - 1
               f_c.print ",\n               "
            end
         end
         
         # Finish function call
         f_c.print ");\n"
         
         # Restore stdout and send data to host if catch_stdout == TRUE
         f_c.print "         if (sig_in->" + h['struct_exec'] + ".catch_stdout)\n         {\n"
         f_c.print "            std_restore(stdout, stdout_redirect);\n"
         f_c.print "            send_data(stdout_filename, sender(&sig_in));\n"
         f_c.print "         }\n"

         # Send reply signal
         f_c.print "         send(&sig_out, sender(&sig_in));\n"
         
         # Free incoming signal buffer
         f_c.print "         free_buf(&sig_in);\n"
         f_c.print "         break;\n"
      end
      
      # ----------
      # Print the default case and end the switch statement
      f_c.print "      default:\n"
      f_c.print "         printf(\"Unrecognized signal received. SigNo: %i\\n\", sig_in->sigNo);\n"
      f_c.print "         free_buf(&sig_in);\n"
      f_c.print "         break;\n"
      f_c.print "      } /* End switch */\n"
      
      # ----------
      # Print the ending of the C file
      f_c.print "   } /* End while */\n"
      f_c.print "} /* End OS_PROCESS */\n"
      f_c.print "\n/* End of file*/\n"
      
      # ----------
      # Close the C file
      f_c.close
      #########################################################################
      
      #########################################################################
      # Create signal file
      
      # Open/create the file
      f_sig = File.open(sig_file, "w")
      
      # ----------
      # Print file header to signal file
      f_sig.print "/* " + sig_file_short + " - Signal definitions */\n"
      f_sig.print "/*-------------------------------------------------------------------*/\n"
      f_sig.print "/* WARNING: Do not modify this file. It is automaticaly generated.   */\n"
      f_sig.print "/*          All modifications will be lost when the generator is run.*/\n"  
      f_sig.print "\n"
      
      # ----------
      # Take the signal file name in uppercase and replace '.' with '_'
      # sigfile.sig -> SIGFILE_SIG
      sig_include = sig_file_short.upcase
      sig_include["."] = "_"
      
      # Print preprocessor macro to avoid the signal file to be included several times
      f_sig.print "#ifndef " + sig_include + "\n"
      f_sig.print "#define " + sig_include + "\n\n"
      
      # ----------
      # Print includes
      f_sig.print "#include \"ose.h\"\n"         # SIGSELECT etc.
      
      # Print lines not already written from 'include_table' in the signal file
      include_table.each do |include_item|
         if include_item =~ /^#include [<"](.*)[>"]/
            if $1 != "ose.h"
               f_sig.print include_item + "\n"
            end
         end
      end
    
      # ----------
      # Print utility signals
      f_sig.print "\n/*-------------------------------------------------------------------*/\n"
      f_sig.print "/* Utility signals */\n\n"
      sig_nr = include_utility_signals(f_sig, sig_nr)
      
      # ----------
      # Print the signal definitions for the parsed functions
      f_sig.print "/*-------------------------------------------------------------------*/\n"
      f_sig.print "/* Function signals */\n"
      data.each do |h|
         f_sig.print "\n"
         # # # # # # # # # # # # # #
         # Define the execute signal
         f_sig.print "/* function: " + h['function'] + " */\n"
         f_sig.print "#define " + h['sig_exec'] + " " + (@@options.sigbase + sig_nr).to_s + " /* !-SIGNO(struct " + h['struct_exec'] + ")-! */\n"
         
         # Define the execute struct
         f_sig.print "struct " + h['struct_exec'] + " {\n"
         f_sig.print "   SIGSELECT sigNo;\n"
         f_sig.print "   OSBOOLEAN catch_stdout;\n"
         
         # Print parameters inside struct definition
         h['input'].each do |input|
            f_sig.print "   " + input + ";\n"
         end
         
         # End struct definition
         f_sig.print "};\n"
         
         # Increase the signal number offset
         sig_nr = sig_nr.next
         
         # # # # # # # # # # # # # #
         # Define the reply signal
         f_sig.print "#define " + h['sig_reply'] + " " + (@@options.sigbase + sig_nr).to_s + " /* !-SIGNO(struct " + h['struct_reply'] + ")-! */\n"
         
         # Define the reply struct
         f_sig.print "struct " + h['struct_reply'] + " {\n"
         f_sig.print "   SIGSELECT sigNo;\n"
         
         # Print parameter inside struct definition if needed
         if h['output'] != "void"
            f_sig.print "   " + h['output'] + " return_value;\n"
         end
        
         # End struct definition
         f_sig.print "};\n"
        
         # Increase the signal number offset
         sig_nr = sig_nr.next
      end
      
      # ----------
      # Print the ending of the signal file
      f_sig.print "\n#endif /* " + sig_include + " */\n"
      f_sig.print "\n/* End of file*/\n"
      f_sig.close
      #########################################################################
   end

# End class definition
end

# End of file
