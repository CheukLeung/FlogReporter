$: << File.dirname(__FILE__)

require 'fileutils'
require "TCrubyparse"
require 'set'

class Front
  #
  # Concatenate and read all files.
  #
  # The files are concatenated and preprocessed to generate an array
  # used in phase 2.
  #

  def self.process_files	
  	 str = ""
  	 comment = []
  	 comment_list = []
  	 @@options.files.each do |file| 
  	 	File.open(file, "r") do |infile|
  	 		while (line = infile.gets)
  	 			if line[0].eql?("#")
  	 			    comment.push(line)
  	 			else
	   			    str << line
	   			end
	   	    end
	 	end
	 end	
    
    current_comment = ""
    i = 0
    while i < comment.length do 
        current_comment << comment[i]
        i += 1
        if comment[i].strip.eql?("#############################################")
           current_comment << comment[i]
           comment_list.push(current_comment)
           i += 1
        end
    end
    
    loop do
      next if str.sub!(/^[ \t\f\r]+/o, '')  # Suppress spaces
      next if str.sub!(/^[ \t\f\r]*\n[ \t\f\r]*/o, '')  # Next line        
      break
    end
    return_set = str, comment_list
    return_set
  end


  #
  # Parse the test case files. The parser in the module TCrubyparse is called. It will 
  # return the results in the form of 5 tables: 
  # state_table, ipnut_table, transitions_table.
  #
  def self.cparse(preprocessed_header_files)
    parser = TCrubyparse.new
    begin
      tables = parser.parse(preprocessed_header_files, @@options)
      File.delete("trimmedcppfile") if File.exist?("trimmedcppfile")
      system("zip -q -j debug_files errorfile") if File.exist?("errorfile")
      puts "Parsing OK" if File.exist?("errorfile") == false
      puts "Parsing done but contains error(s)" if File.exist?("errorfile")
      File.delete("errorfile") if File.exist?("errorfile")
    rescue ParseError
      puts $!
      exit
    end
    tables
  end
  
end
