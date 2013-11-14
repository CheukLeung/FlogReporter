require "./test/readFile"
require "./test/GetRef"

require 'simplecov'
SimpleCov.command_name 'test:SigpaUser'
SimpleCov.start
gem 'test-unit'
require 'test/unit' 
require 'ci/reporter/rake/test_unit_loader'
require 'ostruct'

require "./python/user.rb"

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
 
class TC_SigpaUser < Test::Unit::TestCase



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
      @@options.cpp = "/usr/bin/cpp"
      @@options.include_paths = "include"
      @@options.include_files = "include.c"
      @@options.header_files = "header.h"
      @@options.macros = "MARCO=1"
      @@options.outfile = "output.py"
      @@options.help = true
      @@options.verbose = false
      @@options.debug = true
      
      out, err = capture_stdout do
         Printoptions.list
      end  
      ref_options_out = GetRef.new.getOptionsRef()
      assert_equal(ref_options_out, out)
      assert_equal("", err)
  end


  def test_user_parsecommandline
      ref_argv = ["-I include", "-i include.c", "-D MARCO=1", "-o output.py", 
                  "-h", "-v", "-d", "input.c"]
      ref_options = OpenStruct.new
      ref_options.include_paths = ["include"]
      ref_options.include_files = ["include.c"]
      ref_options.macros = [" MARCO=1"]
      ref_options.outfile = " output.py"
      ref_options.help = true
      ref_options.verbose = true
      ref_options.debug = true
      ref_options.header_files = [Dir.pwd + "/input.c"]
      ref_options.directory = Dir.pwd

      option = ParseCommandLine.parse(ref_argv)

      assert_equal(ref_options.include_paths, option.include_paths)
      assert_equal(ref_options.include_files, option.include_files)
      assert_equal(ref_options.macros, option.macros)
      assert_equal(ref_options.help, option.help)      
      assert_equal(ref_options.outfile, option.outfile)
      assert_equal(ref_options.help, option.help)
      assert_equal(ref_options.verbose, option.verbose)
      assert_equal(ref_options.debug, option.debug)
      assert_equal(ref_options.header_files, option.header_files)
      assert_equal(ref_options.directory, option.directory)
      
  end

  def test_user_argumentcheck_1
      @@options.cpp = "/usr/bin/cpp"
      @@options.help = false
      @@options.macros = [" MARCO=1"]
      @@options.outfile = "test.output"
      @@options.directory = Dir.pwd
      @@options.header_files = [Dir.pwd + "/test.input"]

      assert_raise ArgumentError do
         ArgumentCheck.check 
      end
  end

  def test_user_argumentcheck_2
      @@options.cpp = ""
      @@options.include_paths = ["include"]
      @@options.help = false
      @@options.macros = [" MARCO=1"]
      @@options.outfile = "test.output"
      @@options.directory = Dir.pwd
      @@options.header_files = [Dir.pwd + '/' + $0]

      assert_nothing_raised ArgumentError do
         ArgumentCheck.check 
      end
  end


end
