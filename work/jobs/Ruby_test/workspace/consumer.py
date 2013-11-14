import re
import StringIO
import requests
import ConfigParser
from ConfigParser import SafeConfigParser
from xml.etree import ElementTree
from xml.etree.ElementTree import QName

rdf_namespace = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
oslc_namespace = 'http://open-services.net/ns/core#'
dcterms_namespace = 'http://purl.org/dc/terms/'
test_case_namespace = 'http://some.thing/testcase#'
test_case_type = test_case_namespace + 'TestCase'

config_file = "consumer.ini"
testCase_uri = ''

config = ConfigParser.ConfigParser()
config.read(config_file)
resource_uri = config.get('DEFAULT','resource_uri')
destination = './'
file_name_prefix = config.get('DEFAULT','file_name_prefix')

r = requests.get(resource_uri)
xml= StringIO.StringIO( r.content )
root = ElementTree.parse(xml).getroot()

for node in root:
    for subnode in node:
        if subnode.tag == str( QName(  oslc_namespace ,'queryBase') ):
           resource_type = node.find(str( QName(oslc_namespace ,'resourceType')))
           resource = resource_type.get(str( QName(rdf_namespace ,'resource')))
           if resource == test_case_type:
               testCase_uri = subnode.get(str( QName(rdf_namespace ,'resource')))

r = requests.get(testCase_uri)
xml= StringIO.StringIO( r.content )
root = ElementTree.parse(xml).getroot()

for node in root:
    for subnode in node:
        if subnode.tag == str( QName(rdf_namespace ,'type')):
            resource = subnode.get(str( QName(rdf_namespace ,'resource')))
            if resource == test_case_type:
               identifier = node.find(str( QName(dcterms_namespace ,'identifier'))).text
               reqCoverage = node.find(str( QName(test_case_namespace ,'reqCoverage'))).text
               shortName = node.find(str( QName(dcterms_namespace ,'title'))).text
               purpose = node.find(str( QName(test_case_namespace ,'purpose'))).text
               description = node.find(str( QName(dcterms_namespace ,'description'))).text
               testType = node.find(str( QName(dcterms_namespace ,'type'))).text
               level = node.find(str( QName(test_case_namespace ,'level'))).text
               actionEvent = node.find(str( QName(test_case_namespace ,'actionEvent'))).text
               passCriteria = node.find(str( QName(test_case_namespace ,'passCriteria'))).text
               environmentRequirement = node.find(str( QName(test_case_namespace ,'environmentRequirement'))).text
               comment = node.find(str( QName(test_case_namespace ,'comment'))).text
               
               abstractTestCase = node.find(str( QName(test_case_namespace ,'abstractTestCase'))).text
               abstractTestCase = re.sub(r"Trace: [0-9]+/[0-9]+\n", "", abstractTestCase)
               f = open(destination + file_name_prefix + identifier + '.txt', 'w')
               f.write("[SHORTNAME=" + shortName.strip() +"]\n")
               f.write("\n#############################################\n")
               f.write("# [TestCaseSpecification]\n")
               f.write("# " + shortName.replace("\n", "\n# "))
               f.write("[RequirementSpecification]\n")
               f.write("# " + reqCoverage.replace("\n", "\n# "))
               f.write("[Purpose]\n")
               f.write("# " + purpose.replace("\n", "\n# "))
               f.write("[Description]\n")
               f.write("# " + description.replace("\n", "\n# "))
               f.write("[Type]\n")
               f.write("# " + testType.replace("\n", "\n# "))
               f.write("[Level]\n")
               f.write("# " + level.replace("\n", "\n# "))
               f.write("[ActionEvent]\n")
               f.write("# " + actionEvent.replace("\n", "\n# ").strip())
               f.write(" [PassCriteria]\n")
               f.write("# " + passCriteria.replace("\n", "\n# "))
               f.write("[EnvironmentRequirement]\n")
               f.write("# " + environmentRequirement.replace("\n", "\n# "))
               f.write("[Comment]\n")
               f.write("# " + comment.replace("\n", "\n# "))
               f.write("\n#############################################")
               f.write(abstractTestCase)
               f.close()


