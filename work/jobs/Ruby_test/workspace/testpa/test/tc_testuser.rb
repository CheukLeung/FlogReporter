require "./test/readFile"
require "./test/GetTCRef"

require 'simplecov'
SimpleCov.command_name 'test:TestUser'
SimpleCov.start
gem 'test-unit'
require 'test/unit' 
require 'ci/reporter/rake/test_unit_loader'
require 'ostruct'

require "./python/testuser.rb"

require 'rubygems'
require 'stringio'
 
module Kernel
  def capture_stdout
    out = StringIO.new
    err = StringIO.new
    $stdout = out
    $stderr = err
    yield
    return out.string, err.string
  ensure
    $stdout = STDOUT
    $stderr = STDERR
  end
end
 
class TC_TestUser < Test::Unit::TestCase



  def setup
      @@options = OpenStruct.new
  end
  
  def teardown
      # Nothing really
  end
  
  def test_testuser_describe
      out, err = capture_stdout do
         assert_raise SystemExit do
            SyntaxDescription.describe
         end
      end
      ref_help = GetRef.new.getHelpRef()
      assert_equal(ref_help, out)
      assert_equal("", err)
  end
 
  def test_testuser_printoptions
      @@options.outfile = "test.output"
      @@options.help = false
      @@options.verbose = true
      @@options.debug = false
      out, err = capture_stdout do
         Printoptions.list
      end  
      ref_options_out = GetRef.new.getOptionsRef()
      assert_equal(ref_options_out, out)
      assert_equal("", err)
  end
  
  def test_user_parsecommandline
      ref_argv = ["-o test.output", "-h", "-v", "-d", "test.input"]
      ref_options = OpenStruct.new
      ref_options.outfile = " test.output"
      ref_options.help = true
      ref_options.verbose = true
      ref_options.debug = true
      ref_options.files = [Dir.pwd + "/test.input"]
      ref_options.directory = Dir.pwd

      option = ParseCommandLine.parse(ref_argv)
      
      assert_equal(ref_options.outfile, option.outfile)
      assert_equal(ref_options.help, option.help)
      assert_equal(ref_options.verbose, option.verbose)
      assert_equal(ref_options.debug, option.debug)
      assert_equal(ref_options.files, option.files)
      assert_equal(ref_options.directory, option.directory)
      
  end

  def test_user_argumentcheck_1
      @@options.help = false
      @@options.outfile = "test.output"
      @@options.directory = Dir.pwd
      @@options.files = [Dir.pwd + "/test.input"]

      assert_raise ArgumentError do
         ArgumentCheck.check 
      end
  end

end
