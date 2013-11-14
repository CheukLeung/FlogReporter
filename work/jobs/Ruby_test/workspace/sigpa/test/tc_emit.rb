require "./test/readFile"
require "./test/GetRef"

require 'simplecov'
SimpleCov.command_name 'test:Emit'
SimpleCov.start
gem 'test-unit'
require 'test/unit' 
require 'ci/reporter/rake/test_unit_loader'
require 'ostruct'

require "./python/emit.rb"

require 'rubygems'
require 'stringio'

BaiscNode = Struct.new(:name, :s_u_name, :kind) 
TreeNode = Struct.new(:name, :s_u_name, :kind, :level, :parent, :children)
ArrayNode = Struct.new(:name, :s_u_name, :kind, :level, :parent, :children, :arrsize, :leaf)
NumericNode = Struct.new(:name, :s_u_name, :kind, :level, :parent, :children, :basetype)
FullNode = Struct.new(
    :name, :kind, :basetype, :data, :arrsize, :s_u_name, :leaf, :level,
    :size, :align, :parent, :children
) 

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
 

class TC_Emit < Test::Unit::TestCase

  def setup
      # Nothing really
  end
  
  def teardown
      # Nothing really
  end
  
  def test_string_up
      assert_equal("Test", "test".up)
  end
  
  def test_regtally
      regtally = Regtally.instance
      assert_equal(regtally.instance_eval('@regtally'), {})
     
      dummynode = BaiscNode.new("dummynode", "dummy_sig", "numeric")
      assert_equal(regtally.has?(dummynode), false)
      regtally.add(dummynode)
      assert_equal(regtally.has?(dummynode), true)
  end
  
  def test_signalclass_initialize
      dummyroot = BaiscNode.new("dummynode", "dummy_sig", "numeric")
      signal = SignalClass.new(dummyroot, nil, 13121, "DUMMY_SIG")
      assert_equal(dummyroot, signal.instance_eval('@root'))
      assert_equal(nil, signal.instance_eval('@file'))
      assert_equal(13121, signal.instance_eval('@signo'))
      assert_equal("DUMMY_SIG", signal.instance_eval('@name'))
      assert_equal("", signal.instance_eval('@recstr'))
      assert_equal("", signal.instance_eval('@sendstr'))
      assert_equal(0, signal.instance_eval('@ind'))
      assert_equal("", signal.instance_eval('@s'))
      assert_equal(0, signal.instance_eval('@first_child'))
  end
  
  def test_signalclass_makehash
      ref_arraytable = GetRef.new.getArrayTableRef
      ahash = SignalClass.make_hash(ref_arraytable)
      ref_hash = GetRef.new.getHashRef(0)
      assert_equal(ref_hash, ahash)
  end
  
  def test_signalclass_pathfromroot
      dummygrandchild = TreeNode.new("dummygrandchild", "", "numeric", 2, nil, [])
      dummychild = TreeNode.new("dummychild", "", "numeric", 1, nil, [dummygrandchild])
      dummynode = TreeNode.new("dummynode", "dummy_sig", "struct", 0, nil, [dummychild])
      dummygrandchild.parent = dummychild
      dummychild.parent = dummynode
      
      path_dummynode = SignalClass.path_from_root(dummynode)
      path_dummychild = SignalClass.path_from_root(dummychild)
      path_dummygrandchild = SignalClass.path_from_root(dummygrandchild)
      assert_equal("dummynode", path_dummynode)
      assert_equal("dummy_sig.dummychild", path_dummychild)
      assert_equal("dummy_sig.dummychild.dummygrandchild", path_dummygrandchild)
  end
  
  def test_signalclass_ind
      signal = SignalClass.new(nil, nil, 13121, "DUMMY_SIG")
      assert_equal("", signal.ind)
      assert_equal("        ", signal.ind(2))
  end
  
  def test_signalclass_generateattrlist
      dummychild = TreeNode.new("dummychild", "", "numeric", 1, nil, [])
      dummypadding = TreeNode.new("dummypadding", "", "padding", 1, nil, [])
      dummyroot = TreeNode.new("dummyroot", "dummy_sig", "struct", 0, nil,  [dummychild, dummypadding])
      dummychild.parent = dummyroot
      dummypadding.parent = dummyroot

      signal = SignalClass.new(dummyroot, nil, 13121, "TEST_SIG")
      ref_hash = GetRef.new.getHashRef(0)
      signal.generate_attr_list(ref_hash)
      s = signal.instance_eval('@s')
      assert_equal("\n    ATTR_LIST = [\n        'sig_no',\n        'dummychild',\n    ]\n", s)
  end
  
  def test_signalclass_generatesignalclass
      dummychild = TreeNode.new("sig_no", "", "numeric", 1, nil, [])
      dummyroot = TreeNode.new("dummyroot", "dummy_sig", "struct", 0, nil,  [dummychild])
      signalroot = SignalClass.new(dummyroot, nil, 13121, "DUMMY_SIG")
      signalroot.generate_signal_class
      signalroot_class = signalroot.instance_eval('@s')
      ref_signalroot_class = GetRef.new.getSignalRootClassRef
      assert_equal(ref_signalroot_class, signalroot_class)
      
      signalstruct = SignalClass.new(dummyroot, "testsig.py", 0, "")
      signalstruct.generate_signal_class
      signalstruct_class = signalstruct.instance_eval('@s')
      ref_signalstruct_class = GetRef.new.getSignalStructClassRef
      assert_equal(ref_signalstruct_class, signalstruct_class)
  end
  
  def test_signalclass_generateconstructor
      ref_hash = GetRef.new.getHashRef(0)
      dummy_sig_no = TreeNode.new("dummy_sig_no", "", "numeric", 1, nil, [])
      dummy_boolean = TreeNode.new("dummy_boolean", "", "boolean", 1, nil, [])
      dummy_enum = TreeNode.new("dummy_enum", "", "enum", 1, nil, [])
      dummy_struct = TreeNode.new("dummy_struct", "", "struct", 1, nil, [])
      dummy_union = TreeNode.new("dummy_union", "", "union", 1, nil, [])
      dummy_array_1 = ArrayNode.new("dummy_array_1", "number_1", "array", 1, nil, [], 5, false)
      dummy_array_2 = ArrayNode.new("dummy_array_2", "number_2", "array", 1, nil, [], 5, true)
      
      dummyroot = TreeNode.new("dummyroot", "dummy_sig", "struct", 0, nil,  
             [dummy_sig_no, dummy_boolean, dummy_enum, dummy_struct, dummy_union, dummy_array_1, dummy_array_2])
      signalroot = SignalClass.new(dummyroot, nil, 13121, "DUMMY_SIG")
      signalroot.generate_constructor(ref_hash)
      signalroot_constructor = signalroot.instance_eval('@s')
      ref_constructor = GetRef.new.getConstructorRef
      assert_equal(ref_constructor, signalroot_constructor)
  end
  
  def test_signalclass_generateprelude
      signal = SignalClass.new(nil, "testsig.py", 13121, "DUMMY_SIG")
      signal.generate_unserialize_prelude
      recstr = signal.instance_eval('@recstr')
      
      signal.generate_serialize_prelude
      sendstr = signal.instance_eval('@sendstr')
      
      assert_equal("\n    def unserialize(self, reader, tag=None):\n", recstr) 
      assert_equal("\n    def serialize(self, writer, tag=None):\n", sendstr) 
  end
  
  def test_signalclass_visitnumeric
      ref_recstr = ["        self.dummychild = reader.readU32()\n",
                    "        _dummychild = reader.readU32()\n"]
      ref_sendstr = ["        writer.writeU32(self.dummychild)\n",
                     "        writer.writeU32(len(self.data_size))\n"]
      ref_hash = GetRef.new.getHashRef(0)
      dummychild = NumericNode.new("dummychild", "", "numeric", 1, nil, [], "U32")
      dummynode = TreeNode.new("dummynode", "dummy_sig", "struct", 0, nil, [dummychild])
      dummychild.parent = dummynode
      signal = SignalClass.new(dummynode, nil, 13121, "DUMMY_SIG")
      signal.visit_numeric(ref_hash, dummychild)
      recstr = signal.instance_eval('@recstr')
      sendstr = signal.instance_eval('@sendstr')
      assert_equal(ref_recstr[0], recstr) 
      assert_equal(ref_sendstr[0], sendstr) 
      
      ref_hash = GetRef.new.getHashRef(1)
      signal = SignalClass.new(dummynode, nil, 13121, "DUMMY_SIG")
      signal.visit_numeric(ref_hash, dummychild)
      recstr = signal.instance_eval('@recstr')
      sendstr = signal.instance_eval('@sendstr')
      assert_equal(ref_recstr[1], recstr) 
      assert_equal(ref_sendstr[1], sendstr) 
  end
  
  def test_signalclass_visitenum
      dummynode = BaiscNode.new("dummynode", "", "")
      signal = SignalClass.new(dummynode, nil, 13121, "DUMMY_SIG")
      signal.visit_enum(nil, dummynode)
      recstr = signal.instance_eval('@recstr')
      sendstr = signal.instance_eval('@sendstr')
      assert_equal("        self.dummynode = reader.readS32()\n", recstr) 
      assert_equal("        writer.writeS32(self.dummynode)\n", sendstr) 
  end
  
  def test_signalclass_visitarray_1
      ref_recstr = "        self.dummy_array = reader.int_array(5, 5, reader.read)\n"
      ref_sendstr = "        writer.int_array(self.dummy_array, 5, writer.write)\n"
  
      ref_hash = GetRef.new.getHashRef(1)
      
      dummy_array = FullNode.new( "dummy_array", "array", nil, nil, 5, 
                                    "number", true, 1, 20, 8, nil, [])
      dummyroot = TreeNode.new("dummyroot", "dummy_sig", "struct", 0, nil, [dummy_array])
      dummy_array.parent = dummyroot
      
      signal = SignalClass.new(dummyroot, nil, 13121, "DUMMY_SIG")
      signal.visit_array(ref_hash, dummy_array)
      recstr = signal.instance_eval('@recstr')
      sendstr = signal.instance_eval('@sendstr')
      assert_equal(ref_recstr, recstr) 
      assert_equal(ref_sendstr, sendstr) 
  end

  def test_signalclass_visitarray_2
      ref_recstr = "        self.dummy_array = reader.composite_array(number, 5, 5, reader.struct)\n"
      ref_sendstr = "        writer.composite_array(number, self.dummy_array, 5, writer.struct)\n"
  
      ref_hash = GetRef.new.getHashRef(1)
      
      dummy_array = FullNode.new( "dummy_array", "array", nil, nil, 5, 
                                    "number", false, 1, 20, 8, nil, [])
      dummyroot = TreeNode.new("dummyroot", "dummy_sig", "struct", 0, nil, [dummy_array])
      dummy_array.parent = dummyroot
      
      file = File.open("test/testsig.py", "w")
      
      signal = SignalClass.new(dummyroot, file, 13121, "DUMMY_SIG")
      signal.visit_array(ref_hash, dummy_array)
      file.close
      
      recstr = signal.instance_eval('@recstr')
      sendstr = signal.instance_eval('@sendstr')
      assert_equal(ref_recstr, recstr) 
      assert_equal(ref_sendstr, sendstr) 
      ref_testsig = ReadFile.new.readInTC("test/ref/ref_testsig_array.py")
      testsig = ReadFile.new.readInTC("test/testsig.py")
      assert_equal(ref_testsig, testsig)
      File.delete("test/testsig.py") if File.exist?("test/testsig.py")
  end
  
  def test_signalclass_guessdynarray_1
      hash = Marshal.load( Marshal.dump(GetRef.new.getHashRef(2)) )
      ref_hash = GetRef.new.getHashRef(3)
      dummychild = FullNode.new( "dummychild", "numeric", "U32", nil, 0, 
                                    "", true, 1, 4, 4, nil, [])
      dummy_array = FullNode.new( "dummy_array", "array", nil, nil, 1, 
                                    "number", true, 1, 20, 8, nil, [])
      dummyroot = TreeNode.new("dummyroot", "dummy_sig", "struct", 0, nil, [dummychild, dummy_array])
      dummychild.parent = dummyroot
      dummy_array.parent = dummyroot
      
      signal = SignalClass.new(dummyroot, nil, 13121, "DUMMY_SIG")
      signal.guess_dyn_array(hash)
      assert_equal(ref_hash, hash)
  end
 
  def test_signalclass_guessdynarray_2
      hash = Marshal.load( Marshal.dump(GetRef.new.getHashRef(2)) )
      dummy_array = FullNode.new( "dummy_array", "array", nil, nil, 1, 
                                    "number", true, 1, 20, 8, nil, [])
      dummyroot = TreeNode.new("dummyroot", "dummy_sig", "struct", 0, nil, [dummy_array])
      dummy_array.parent = dummyroot
      
      signal = SignalClass.new(dummyroot, nil, 13121, "DUMMY_SIG")
      out, err = capture_stdout do
          signal.guess_dyn_array(hash)
      end  
      ref_out = GetRef.new.getCannotGuessRef
      assert_equal(ref_out, out)
      assert_equal("", err)
  end
  
  def test_signalclass_visitstruct
      dummyroot = FullNode.new( "dummyroot", "struct", nil, nil, 0, 
                                    "dummy_sig", false, 0, 4, 4, nil, [])                             
      ref_hash = GetRef.new.getHashRef(0)
      
      signal = SignalClass.new(dummyroot,  nil, 13121, "DUMMY_SIG")
      signal.visit_struct(ref_hash, dummyroot)
      
      recstr = signal.instance_eval('@recstr')
      sendstr = signal.instance_eval('@sendstr')
      assert_equal("        self.dummyroot.unserialize(reader)\n", recstr) 
      assert_equal("        self.dummyroot.serialize(writer)\n", sendstr) 
      
      ref_hash = GetRef.new.getHashRef(1)
      signal = SignalClass.new(dummyroot,  nil, 13121, "DUMMY_SIG")
      signal.visit_struct(ref_hash, dummyroot)
      
      recstr = signal.instance_eval('@recstr')
      sendstr = signal.instance_eval('@sendstr')
      assert_equal("        self.dummyroot.unserialize(reader, self.selector_variable)\n", recstr) 
      assert_equal("        self.dummyroot.serialize(writer, self.selector_variable)\n", sendstr) 
  end

  def test_signalclass_visitnode_1
      dummychild = FullNode.new( "dummychild", "numeric", "U32", nil, 0, 
                                    "", true, 1, 4, 4, nil, [])
      dummyroot = FullNode.new( "dummyroot", "struct", nil, nil, 0, 
                                    "dummy_sig", false, 0, 4, 4, nil, [dummychild])                             
      dummychild.parent = dummyroot
      ref_hash = GetRef.new.getHashRef(1)
      
      signal = SignalClass.new(dummyroot, nil, 13121, "DUMMY_SIG")
      signal.visit_nodes(ref_hash)
      recstr = signal.instance_eval('@recstr')
      sendstr = signal.instance_eval('@sendstr')
      ind = signal.instance_eval('@ind')
      assert_equal("        _dummychild = reader.readU32()\n        pass\n", recstr)
      assert_equal("        writer.writeU32(len(self.data_size))\n        pass\n", sendstr)
      assert_equal(0, ind)
  end
 
  def test_signalclass_visitnode_2
      dummychild = FullNode.new( "dummychild", "struct", "U32", nil, 0, 
                                    "", true, 1, 4, 4, nil, [])
      dummyroot = FullNode.new( "dummyroot", "struct", nil, nil, 0, 
                                    "dummy_sig", false, 0, 4, 4, nil, [dummychild])                             
      dummychild.parent = dummyroot
      ref_hash = GetRef.new.getHashRef(1)

      file = File.open("test/testsig.py", "w")
      signal = SignalClass.new(dummyroot, file, 13121, "DUMMY_SIG")
      signal.visit_nodes(ref_hash)
      file.close
      recstr = signal.instance_eval('@recstr')
      sendstr = signal.instance_eval('@sendstr')
      ind = signal.instance_eval('@ind')
      assert_equal("        self.dummychild.unserialize(reader)\n        pass\n", recstr)
      assert_equal("        self.dummychild.serialize(writer)\n        pass\n", sendstr)
      assert_equal(0, ind)
      ref_testsig = ReadFile.new.readInTC("test/ref/ref_testsig_struct.py")
      testsig = ReadFile.new.readInTC("test/testsig.py")
      assert_equal(ref_testsig, testsig)
      File.delete("test/testsig.py") if File.exist?("test/testsig.py")
  end
  
  def test_signalclass_visitnode_3
      dummychild = FullNode.new( "dummychild", "numeric", "U32", nil, 0, 
                                    "", true, 1, 4, 4, nil, [])
      dummyroot = FullNode.new( "dummyroot", "union", nil, nil, 0, 
                                    "dummy_sig", false, 0, 4, 4, nil, [dummychild])                             
      dummychild.parent = dummyroot
      ref_hash = GetRef.new.getHashRef(1)
      
      signal = SignalClass.new(dummyroot, nil, 13121, "DUMMY_SIG")
      signal.visit_nodes(ref_hash)
      recstr = signal.instance_eval('@recstr')
      sendstr = signal.instance_eval('@sendstr')
      ind = signal.instance_eval('@ind')
      ref_recstr = GetRef.new.getVisitNodeUnionRecstr
      ref_sendstr = GetRef.new.getVisitNodeUnionSendstr
      assert_equal(ref_recstr, recstr)
      assert_equal(ref_sendstr, sendstr)
      assert_equal(0, ind)
  end

  def test_signalclass_visitnode_4
      dummychild = FullNode.new( "dummychild", "enum", "U32", nil, 0, 
                                    "", true, 1, 4, 4, nil, [])
      dummyroot = FullNode.new( "dummyroot", "struct", nil, nil, 0, 
                                    "dummy_sig", false, 0, 4, 4, nil, [dummychild])                             
      dummychild.parent = dummyroot
      ref_hash = GetRef.new.getHashRef(1)
      
      signal = SignalClass.new(dummyroot, nil, 13121, "DUMMY_SIG")
      signal.visit_nodes(ref_hash)
      recstr = signal.instance_eval('@recstr')
      sendstr = signal.instance_eval('@sendstr')
      ind = signal.instance_eval('@ind')
      assert_equal("        self.dummychild = reader.readS32()\n        pass\n", recstr)
      assert_equal("        writer.writeS32(self.dummychild)\n        pass\n", sendstr)
      assert_equal(0, ind)
  end

  def test_signalclass_visitnode_5
      dummychild = FullNode.new( "dummychild", "array", "U32", nil, 0, 
                                    "", true, 1, 4, 4, nil, [])
      dummyroot = FullNode.new( "dummyroot", "struct", nil, nil, 0, 
                                    "dummy_sig", false, 0, 4, 4, nil, [dummychild])                             
      dummychild.parent = dummyroot
      ref_hash = GetRef.new.getHashRef(1)
      
      signal = SignalClass.new(dummyroot, nil, 13121, "DUMMY_SIG")
      signal.visit_nodes(ref_hash)
      recstr = signal.instance_eval('@recstr')
      sendstr = signal.instance_eval('@sendstr')
      ind = signal.instance_eval('@ind')
      ref_recstr = GetRef.new.getVisitNodeUnionRecstr
      ref_sendstr = GetRef.new.getVisitNodeUnionSendstr
      assert_equal("        self.dummychild = reader.int_array(0, 0, reader.readU32)\n        pass\n", recstr)
      assert_equal("        writer.int_array(self.dummychild, 0, writer.writeU32)\n        pass\n", sendstr)
      assert_equal(0, ind)
  end
 
  def test_signalclass_s
      signal = SignalClass.new(nil, "testsig.py", 13121, "DUMMY_SIG")
      assert_equal("", signal.s) 
  end 
end
