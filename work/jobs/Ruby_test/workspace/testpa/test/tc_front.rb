require "./test/readFile"
require "./test/GetTCRef"

require 'simplecov'
SimpleCov.command_name 'test:Front'
SimpleCov.start
gem 'test-unit'
require 'test/unit' 
require 'ci/reporter/rake/test_unit_loader'
require 'ostruct'

require "./lib/front.rb"

require 'rubygems'

@@options = OpenStruct.new
 
class TC_Front < Test::Unit::TestCase

  def setup
      # Nothing really
  end
  
  def teardown
      # Nothing really
  end
  
  def test_front_process_files
      @@options = OpenStruct.new
      @@options.files = ["test/ref/ref_abstracttestcase.txt"]
      ref_str = GetRef.new.getParsedStringRef()
      str, comment_list = Front.process_files()
      assert_equal(ref_str, str)
      assert_equal([], comment_list)
  end

  def test_front_comment
      @@options.files = ["test/ref/ref_comment.txt"]
      ref_comment_list = GetRef.new.getCommentListRef()
      str, comment_list = Front.process_files()
      assert_equal("", str)
      assert_equal(ref_comment_list, comment_list)
  end

  def test_front_cparse
      ref_str = GetRef.new.getParsedStringRef()
      state_list, input_list, transitions_list, name_list = Front.cparse(ref_str)
      ref_state_list, ref_input_list, ref_transitions_list, ref_name_list = GetRef.new.getTCRef(2)
      assert_equal(ref_state_list, state_list)
      assert_equal(ref_input_list, input_list)
      assert_equal(ref_transitions_list, transitions_list)
      assert_equal(ref_name_list, name_list)
  end
  
end
