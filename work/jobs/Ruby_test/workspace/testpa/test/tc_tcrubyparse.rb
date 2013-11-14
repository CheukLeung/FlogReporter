require "./test/readFile"
require "./test/GetTCRef"

require 'simplecov'
SimpleCov.command_name 'test:TCrubyparse'
SimpleCov.start
gem 'test-unit'
require 'test/unit' 
require 'ci/reporter/rake/test_unit_loader'
require 'ostruct'

require "./lib/TCrubyparse.rb"
require 'rubygems'

@@options = OpenStruct.new
@@options.files = [""]

class TC_TCrubyparse < Test::Unit::TestCase

  def setup
    @parser = TCrubyparse.new
  end
  
  def teardown
      # Nothing really
  end
  
  def test_parser_tables
      input = ReadFile.new.readInTC("test/ref/abstractTC_template.txt")
      state_list, input_list, transitions_list, name_list = @parser.parse(input,@@options)
      ref_state_list, ref_input_list, ref_transitions_list, ref_name_list = GetRef.new.getTCRef(0)
      assert_equal(ref_state_list, state_list)
      assert_equal(ref_input_list, input_list)
      assert_equal(ref_transitions_list, transitions_list)
      assert_equal(ref_name_list, name_list)
  end

  def test_parser_transition
      input = ReadFile.new.readInTC("test/ref/transistion_template.txt")
      state_list, input_list, transitions_list, name_list = @parser.parse(input,@@options)
      ref_state_list, ref_input_list, ref_transitions_list, ref_name_list = GetRef.new.getTCRef(1)
      assert_equal(ref_state_list, state_list)
      assert_equal(ref_input_list, input_list)
      assert_equal(ref_transitions_list, transitions_list)
      assert_equal(ref_name_list, name_list)
  end
    
  def test_parser_atc
      input = ReadFile.new.readInTC("test/ref/ref_abstracttestcase.txt")
      state_list, input_list, transitions_list, name_list = @parser.parse(input,@@options)
      ref_state_list, ref_input_list, ref_transitions_list, ref_name_list = GetRef.new.getTCRef(2)
      assert_equal(ref_state_list, state_list)
      assert_equal(ref_input_list, input_list)
      assert_equal(ref_transitions_list, transitions_list)
      assert_equal(ref_name_list, name_list)
  end

end
