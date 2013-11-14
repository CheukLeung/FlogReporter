require 'open-uri'
require 'xmlsimple'

resource_uri = 'http://localhost:8080/OSLC4JRegistry/catalog'
destination = './'
file_name_prefix = 'abstracttestcase_'
testCase_uri = ''

class Consumer
    def get_testCase()
        resource_uri = 'http://localhost:8080/OSLC4JRegistry/catalog'
        destination = './'
        file_name_prefix = 'abstracttestcase_'
        testCase_uri = ''
        conf_file = 'consumer.ini'
        f = File.open(conf_file, "r")
        while (line = f.gets)
            if line.match(/resource_uri = (.*)/)
                testCase_uri = line.match(/resource_uri = (.*)/)[1]
            end
            
            if line.match(/destination = (.*)/)
                destination = line.match(/destination = (.*)/)[1]
            end
            
            if line.match(/file_name_prefix = (.*)/)
                file_name_prefix =line.match(/file_name_prefix = (.*)/)[1]
            end
        end


        web_contents = open(resource_uri) {|f| f.read }
        data = XmlSimple.xml_in(web_contents)

        data["Description"].each do |description|
            if description.has_key?("resourceType")
                description["resourceType"].each do |resource_type|
                    if resource_type["rdf:resource"] == "http://some.thing/testcase#TestCase"
                        if description.has_key?("queryBase")
                            testCase_uri = description["queryBase"][0]["rdf:resource"]
                        end
                    end
                end
            end
        end
        testCase_uri
        
        web_contents = open(testCase_uri) {|f| f.read }
        data = XmlSimple.xml_in(web_contents)

        allTC = ''

        data["Description"].each do |description|
            if description["type"][0]["rdf:resource"] == "http://some.thing/testcase#TestCase"
                aTC = description["abstractTestCase"][0].sub!(%r"Trace: [0-9]+/[0-9]+\n", '')
                
                FileUtils.mkdir_p(destination) unless File.directory?(destination)
                ofname = "#{destination}#{file_name_prefix}#{description["identifier"][0]}.txt"
                f = File.open(ofname, "w")
                f.puts "#{aTC}"
                f.close
                allTC << aTC
            end
        end 

        loop do
            next if allTC.sub!(/^[ \t\f\r]+/o, '')  # Suppress spaces
            next if allTC.sub!(/^[ \t\f\r]*\n[ \t\f\r]*/o, '')  # Next line        
            break
        end
        allTC
    end
end
