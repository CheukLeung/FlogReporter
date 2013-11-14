# ReadFile.rb
   
class ReadFile
   def readInTC(file)
      str = ""
    	File.open(file, "r") do |infile|
    		while (line = infile.gets)
      			str << line
      		end
    	end
    	str
   end
end
