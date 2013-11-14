require "./test/readFile"
require "./test/GetRef"

require 'simplecov'
SimpleCov.command_name 'test:SigpaFront'
SimpleCov.start
gem 'test-unit'
require 'test/unit' 
require 'ci/reporter/rake/test_unit_loader'
require 'ostruct'

require "./lib/front.rb"

require 'rubygems'
@@options = OpenStruct.new 
 
class TC_SigpaFront < Test::Unit::TestCase

  def setup
      # Nothing really
  end
  
  def teardown
      # Nothing really
  end
  
  def test_sigpafront_processheaderfiles
      @@options = OpenStruct.new
      @@options.include_files = []
      @@options.include_paths = []
      @@options.macros = []
      @@options.cpp = "/usr/bin/cpp"
      @@options.header_files = ["test/ref/ref_signals.sig"]
      @@options.verbose = false
      #ref_str = GetRef.new.getParsedStringRef()
      atable, ctable, cpp_str = Front.process_header_files()
      assert_equal(GetRef.new.getATableRef, atable)
      
      assert_equal(GetRef.new.getCTableRef_2, ctable)
      assert_equal(GetRef.new.getCppStrRef, cpp_str)
 
  end
 
  def test_sigpafront_atcsignals_1
      @@options = OpenStruct.new
      @@options.include_files = []
      @@options.include_paths = ["test/ref/ref_atc_signals", "test/ref/ref_atc_signals/linx_linux_headers"]
      @@options.macros = []
      @@options.cpp = "/usr/bin/cpp"
      @@options.header_files = ["test/ref/ref_atc_signals/signals.sig"]
      @@options.verbose = false
      #ref_str = GetRef.new.getParsedStringRef()
      atable, ctable, cpp_str = Front.process_header_files()
      
      ref_cpp_str = ReadFile.new.readInTC("test/ref/ref_processed_cppstr.txt")

      assert_equal(GetRef.new.getATableRef_2, atable)
      
      assert_equal(GetRef.new.getCTableRef_3, ctable)
      assert_equal(ref_cpp_str, cpp_str)
 
  end
  
  def test_sigpafront_atcsignals_2
      @@options = OpenStruct.new
      @@options.include_files = []
      @@options.include_paths = ["test/ref/ref_atc_signals", "test/ref/ref_atc_signals/linx_linux_headers"]
      @@options.macros = []
      @@options.cpp = "/usr/bin/cpp"
      @@options.header_files = ["test/ref/ref_atc_signals/signals.sig"]
      @@options.verbose = false
      @@options.debug = true
      @@options.args = ["-I test/ref/ref_atc_signals", "-I test/ref/ref_atc_signals/linx_linux_headers"]
      #ref_str = GetRef.new.getParsedStringRef()
      atable, ctable, cpp_str = Front.process_header_files()
      
      tables = Front.cparse(cpp_str)
      ref_tables = GetRef.new.getGeneratedTablesRef()
      assert_equal(ref_tables, tables)
  end

end
