require "./test/readFile"
require "./test/GetRef"

require 'simplecov'
SimpleCov.command_name 'test:Linx4PyBack'
SimpleCov.start
gem 'test-unit'
require 'test/unit' 
require 'ci/reporter/rake/test_unit_loader'
require 'ostruct'

require "./linx4py/back.rb"
require 'rubygems'

@@options = OpenStruct.new
@@options.files = [""]

class TC_Linx4PyBack < Test::Unit::TestCase

  def setup
      @pythonback = Back.new
      @@grove = {}
      @@anonext = 0
  end

  def teardown
      # Nothing really
  end

  def test_back_getanonext
      assert_equal(0, Back.class_eval("@@anonext"))
      anonext = get_anon_ext
      assert_equal("1", anonext)
      assert_equal(1, Back.class_eval("@@anonext"))
  end

  def test_back_deepcopy
      ref_test = ["testing"]
      test = ref_test.deepcopy
      test[0] = "changed"
      assert_not_equal(ref_test, test)
      assert_not_same(ref_test, test)
  end
  
  def test_back_itemtype
      test_elem = ["", {".type" => "testing"}]
      type = @pythonback.item_type(test_elem)
      assert_equal("testing", type)
  end
  
  def test_back_itemname
      test_elem = ["", {}]
      name = @pythonback.item_name(test_elem)
      assert_equal("__ANON__", name)
      
      test_elem = ["", {".type_or_id_name" => "(test): test_elem_1"}]
      name = @pythonback.item_name(test_elem)
      assert_equal("test_elem_1", name)
  end

  def test_back_itembasetype
      test_elem = ["", {".type" => "int"}]
      basetype = @pythonback.item_basetype(test_elem)
      assert_equal("c_int", basetype)
      
      test_elem = ["", {".type" => "int", ".signed" => "unsigned"}]
      basetype = @pythonback.item_basetype(test_elem)
      assert_equal("c_uint", basetype)
  end 

  def test_back_baserefname
      test_elem = ["", {".base_ref_name" => "(test): test_elem_base_ref"}]
      baserefname = @pythonback.baseref_name(test_elem)
      assert_equal("test_elem_base_ref", baserefname)
  end 
  
  def test_back_isnumeric
      test_elem_0 = ["", {".type" => "char"}]
      test_elem_1 = ["", {".type" => "short"}]
      test_elem_2 = ["", {".type" => "int"}]
      test_elem_3 = ["", {".type" => "long"}]
      test_elem_4 = ["", {".type" => "longlong"}]
      test_elem_5 = ["", {".type" => "String"}]
      
      assert(@pythonback.is_numeric?(test_elem_0))
      assert(@pythonback.is_numeric?(test_elem_1))
      assert(@pythonback.is_numeric?(test_elem_2))
      assert(@pythonback.is_numeric?(test_elem_3))
      assert(@pythonback.is_numeric?(test_elem_4))
      assert_equal(nil, @pythonback.is_numeric?(test_elem_5))
  end
  
  def test_back_generatesignaldescription
      @@options = OpenStruct.new
      @@options.header_files = ["test/tc_back.rb"]
      @@options.outfile = "test/signals.py"
      atable = GetRef.new.getATableRef
      ctable = GetRef.new.getCTableRef
      tables = GetRef.new.getTablesRef
      @pythonback.generate_signal_description(atable, ctable, tables)
      
      ref_signals = ReadFile.new.readInTC("test/ref/ref_signals_linx4py.py")
      signals = ReadFile.new.readInTC("test/signals.py")
      assert_equal(ref_signals, signals)
      File.delete("test/signals.py") if File.exist?("test/signals.py")
  end 
  
  def test_back_atcsignals
      @@options = OpenStruct.new
      @@options.header_files = ["test/tc_back.rb"]
      @@options.outfile = "test/signals.py"
      atable = {"ARRAY_SIZE"=>[],
 "DENSE_UNION"=>[],
 "SELECTOR_MAPPING"=>[],
 "UNION_SELECTOR"=>[]}
      
      ctable = {"ABSFL_INPUT_SIG"=>{"struct"=>["absfl_input_sig"], "value"=>13121},
 "ABSFL_OUTPUT_SIG"=>{"struct"=>["absfl_output_sig"], "value"=>13122}}
 
      tables = GetRef.new.getGeneratedTablesRef()
      @pythonback.generate_signal_description(atable, ctable, tables)
      ref_signals = ReadFile.new.readInTC("test/ref/ref_atc_signals/signals_linx4py.py")
      signals = ReadFile.new.readInTC("test/signals.py")
      assert_equal(ref_signals, signals)
      File.delete("test/signals.py") if File.exist?("test/signals.py")
  end
  
end
