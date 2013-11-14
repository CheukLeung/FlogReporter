require "./test/readFile"
require "./test/GetRef"

require 'simplecov'
SimpleCov.command_name 'test:Tree'
SimpleCov.start
gem 'test-unit'
require 'test/unit' 
require 'ci/reporter/rake/test_unit_loader'
require 'ostruct'

require "./lib/tree.rb"

require 'rubygems'
@@options = OpenStruct.new 

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
 
class TC_Tree < Test::Unit::TestCase

  def setup
      # Nothing really
  end
  
  def teardown
      # Nothing really
  end
  
  def test_tree_initialize
      tree = Tree.new("Test", "TestType", nil, 5)
      assert_equal("Test", tree.instance_eval('@name'))
      assert_equal("TestType", tree.instance_eval('@kind'))
      assert_equal(nil, tree.instance_eval('@basetype'))
      assert_equal(5, tree.instance_eval('@arrsize'))
      assert_equal("", tree.instance_eval('@s_u_name'))
      assert_equal(false, tree.instance_eval('@leaf'))
      assert_equal(0, tree.instance_eval('@level'))
      assert_equal(0, tree.instance_eval('@size'))
      assert_equal(0, tree.instance_eval('@align'))
      assert_equal(nil, tree.instance_eval('@parent'))
      assert_equal([], tree.instance_eval('@children'))
  end
  
  def test_tree_createchild
      tree = Tree.new("Test", "parent", nil)
      child = Tree.new("Child", "child", nil)
      tree.create_child(child)
      assert_equal([child], tree.instance_eval('@children'))
  end
  
  def test_tree_isleaf
      tree = Tree.new("Test", "parent", nil)
      child = Tree.new("Child", "child", nil)
      tree.create_child(child)
      assert_equal(false, tree.is_leaf?())
      assert(child.is_leaf?())
  end 
  
  def test_tree_haschild
      tree = Tree.new("Test", "parent", nil)
      child = Tree.new("Child_1", "child", nil)
      tree.create_child(child)
      assert(Tree.has_child?(tree, "Child_1"))
      assert_equal(false, Tree.has_child?(tree, "Child_2"))
  end
  
  def test_tree_getchild
      tree = Tree.new("Test", "parent", nil)
      child = Tree.new("Child_1", "child", nil)
      tree.create_child(child)
      assert_equal(child, Tree.get_child(tree, "Child_1"))
      assert_equal(nil, Tree.get_child(tree, "Child_2"))
  end

  def test_tree_issigno
      root = Tree.new("test_sig", "sig_no", nil)
      sig_no = Tree.new("test_sig", "sig_no", nil)
      child = Tree.new("Child_1", "child", nil)
      root.create_child(sig_no)
      assert(Tree.is_signo?(root, sig_no))
      assert_equal(false, Tree.is_signo?(root, child))
  end
  
  def test_tree_printout
      tree = Tree.new("Test", "TestType", nil, 5)
      out, err = capture_stdout do
          Tree.printout(tree)
      end  
      assert_equal(GetRef.new.getTreePrintOutRef(0), out)
  end

  def test_tree_outputtier
      tree = Tree.new("Test", "parent", nil)
      child_1 = Tree.new("Child_1", "child", tree)
      child_2 = Tree.new("Child_2", "child", tree)
      grandchild_1 = Tree.new("Grandchild_1", "grandchild", child_1)
      grandchild_2 = Tree.new("Grandchild_2", "grandchild", child_1)
      tree.create_child(child_1)
      tree.create_child(child_2)
      child_1.create_child(grandchild_1)
      child_1.create_child(grandchild_2)
      
      out, err = capture_stdout do
          Tree.output_tier([tree], 10)
      end  
      assert_equal(GetRef.new.getTreePrintOutRef(1), out)
  end
  
  def test_tree_levelprint
      tree = Tree.new("Test", "parent", nil)
      child_1 = Tree.new("Child_1", "child", tree)
      child_2 = Tree.new("Child_2", "child", tree)
      grandchild_1 = Tree.new("Grandchild_1", "grandchild", child_1)
      grandchild_2 = Tree.new("Grandchild_2", "grandchild", child_1)
      tree.create_child(child_1)
      tree.create_child(child_2)
      child_1.create_child(grandchild_1)
      child_1.create_child(grandchild_2)
      
      out, err = capture_stdout do
          Tree.level_print(tree, 10)
      end
      assert_equal(GetRef.new.getTreePrintOutRef(2), out)
  end
  
  def test_tree_height
      tree = Tree.new("Test", "parent", nil)
      child_1 = Tree.new("Child_1", "child", tree)
      child_2 = Tree.new("Child_2", "child", tree)
      grandchild_1 = Tree.new("Grandchild_1", "grandchild", child_1)
      grandchild_2 = Tree.new("Grandchild_2", "grandchild", child_1)
      tree.create_child(child_1)
      tree.create_child(child_2)
      child_1.create_child(grandchild_1)
      child_1.create_child(grandchild_2)
             
      tree.level = 0;
      child_1.level = 1;
      child_2.level = 1;
      grandchild_1.level = 2;
      grandchild_2.level = 2;
            
      assert_equal(2, Tree.height(tree))
      assert_equal(1, Tree.height(child_1))
      assert_equal(0, Tree.height(child_2))
      assert_equal(0, Tree.height(grandchild_1))
      assert_equal(0, Tree.height(grandchild_2)) 
  end

  def test_tree_size  
      tree = Tree.new("Test", "parent", nil)
      child_1 = Tree.new("Child_1", "child", tree)
      child_2 = Tree.new("Child_2", "child", tree)
      grandchild_1 = Tree.new("Grandchild_1", "grandchild", child_1)
      grandchild_2 = Tree.new("Grandchild_2", "grandchild", child_1)
      tree.create_child(child_1)
      tree.create_child(child_2)
      child_1.create_child(grandchild_1)
      child_1.create_child(grandchild_2)
      
      assert_equal(5, Tree.size(tree))
      assert_equal(3, Tree.size(child_1))
      assert_equal(1, Tree.size(child_2))
      assert_equal(1, Tree.size(grandchild_1))
      assert_equal(1, Tree.size(grandchild_2)) 
  end
  
  def test_tree_getpath
      tree = Tree.new("Test", "parent", nil)
      child_1 = Tree.new("Child_1", "child", tree)
      child_2 = Tree.new("Child_2", "child", tree)
      grandchild_1 = Tree.new("Grandchild_1", "grandchild", child_1)
      grandchild_2 = Tree.new("Grandchild_2", "grandchild", child_1)
      tree.create_child(child_1)
      tree.create_child(child_2)
      child_1.create_child(grandchild_1)
      child_1.create_child(grandchild_2)
      
      assert_equal("Child_1", Tree.get_path(child_1))
      assert_equal("Child_2", Tree.get_path(child_2))
      assert_equal("Child_1.Grandchild_1", Tree.get_path(grandchild_1))
      assert_equal("Child_1.Grandchild_2", Tree.get_path(grandchild_2)) 
  end
  
  def test_tree_preorder
      tree = Tree.new("Test", "parent", nil)
      child = Tree.new("Child", "child", nil)
      tree.create_child(child)
             
      tree.level = 0;
      child.level = 1;
      
      out, err = capture_stdout do
          Tree.preorder(child)
      end
      assert_equal(GetRef.new.getTreePrintOutRef(3),out)
  end

  def test_tree_postorder
      tree = Tree.new("Test", "parent", nil)
      child = Tree.new("Child", "child", nil)
      tree.create_child(child)
             
      tree.level = 0;
      child.level = 1;
      
      out, err = capture_stdout do
          Tree.postorder(child)
      end
      assert_equal(GetRef.new.getTreePrintOutRef(3),out)
  end
  
  def test_tree_levelorderaux
      tree = Tree.new("Test", "parent", nil)
      child = Tree.new("Child", "child", nil)
      tree.create_child(child)
             
      tree.level = 0;
      child.level = 1;
      
      out, err = capture_stdout do
          Tree.levelorder_aux(child, 1)
      end
      assert_equal(GetRef.new.getTreePrintOutRef(3),out)
      
      out, err = capture_stdout do
          Tree.levelorder_aux(tree, 2)
      end
      assert_equal(GetRef.new.getTreePrintOutRef(3),out)
      
  end
  
  def test_tree_levelorder
      tree = Tree.new("Test", "parent", nil)
      child = Tree.new("Child", "child", nil)
      tree.create_child(child)
             
      tree.level = 0;
      child.level = 1;
      
      out, err = capture_stdout do
          Tree.levelorder(child)
      end
      assert_equal(GetRef.new.getTreePrintOutRef(3),out)
  end
  
  
end
