require "./test/readFile"
require "./test/GetTCRef"

require 'simplecov'
SimpleCov.command_name 'test:Linx4PyBack'
SimpleCov.start
gem 'test-unit'
require 'test/unit' 
require 'ci/reporter/rake/test_unit_loader'
require 'ostruct'

require "./linx4py/testcaseback.rb"
require 'rubygems'

@@options = OpenStruct.new
@@options.files = [""]

class TC_Linx4PyBack < Test::Unit::TestCase

  def setup
    @pythonback = TestCaseBack.new
  end

  def teardown
      # Nothing really
  end

  def test_backend_output
      @@options.outfile = "test/output_linx4py.py"
      tables = GetRef.new.getTCRef(2)
      comment_list = []
      @pythonback.generate_test_cases(tables, comment_list)
      ref_output = ReadFile.new.readInTC("test/ref/ref_output_linx4py.py")
      output = ReadFile.new.readInTC("test/output_linx4py.py")
      assert_equal(ref_output, output)
      File.delete("test/output_linx4py.py") if File.exist?("test/output_linx4py.py")
  end
  
  def test_backend_type_h
      @@options.outfile = "test/output.py"
      @pythonback.generate_types_h()
      ref_output = ReadFile.new.readInTC("test/ref/ref_types.h")
      output = ReadFile.new.readInTC("test/types.h")
      assert_equal(ref_output, output)
      File.delete("test/types.h") if File.exist?("test/types.h")
  end
  
  def test_backend_signal
      @@options.outfile = "test/output.py"
      ref_state_list, ref_input_list, ref_transitions_list, ref_name_list = GetRef.new.getTCRef(2)
      @pythonback.generate_signals_sig(ref_input_list[0])
      ref_output_sig = ReadFile.new.readInTC("test/ref/ref_signals.sig")
      ref_output_header = ReadFile.new.readInTC("test/ref/ref_signal_absfl.h")
      output_sig = ReadFile.new.readInTC("test/signals.sig")
      output_header = ReadFile.new.readInTC("test/signal_absfl.h")

      assert_equal(ref_output_sig, output_sig)
      assert_equal(ref_output_header, output_header)
      
      File.delete("test/signals.sig") if File.exist?("test/signals.sig")
      File.delete("test/signal_absfl.h") if File.exist?("test/signal_absfl.h")
  end
  
  def test_backend_atc
      @@options.outfile = "test/testcase_linx4py.py"
      tables = GetRef.new.getTCRef(2)
      ref_comment_list = GetRef.new.getCommentListRef()	
      @pythonback.generate_test_cases(tables, ref_comment_list)
      ref_output = ReadFile.new.readInTC("test/ref/ref_testcase_linx4py.py")
      output = ReadFile.new.readInTC("test/testcase_linx4py.py")
      assert_equal(ref_output, output)
      File.delete("test/testcase_linx4py.py") if File.exist?("test/testcase_linx4py.py")
  end
end
