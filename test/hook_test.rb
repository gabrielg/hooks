require 'test_helper'

class HookTest < MiniTest::Spec
  class HookTester
    attr_accessor :passed_block, :passed_args

    def test_hook(*args, &block)
      @passed_args = *args
      @passed_block = block
      yield if block_given?
    end
  end

  subject { Hooks::Hook.new({:name => :test_hook}) }

  it "exposes array behaviour for callbacks" do
    subject << :play_music
    subject << :drink_beer

    subject.to_a.must_equal [:play_music, :drink_beer]
  end

  describe "#run" do
    it "executes the same-named method when given a Symbol" do
      subject << :captain_hook

      scope = MiniTest::Mock.new
      scope.expect(:captain_hook, nil)
      subject.run(scope)

      scope.verify
    end

    it "instance_execs the Proc when given a block" do
      context = nil

      subject << lambda { context = self }

      scope = Object.new
      subject.run(scope)

      context.must_equal scope
    end

    it "calls a method named after the hook when given another object" do
      hook_object = MiniTest::Mock.new
      scope = Object.new

      subject << hook_object

      hook_object.expect(:test_hook, nil, [scope, :another_arg])

      subject.run(scope, :another_arg)

      hook_object.verify
    end

    it "passes the block to the named method with given a Symbol hook" do
      subject << :test_hook

      expected_block = Proc.new { true }

      # Can't use MiniTest::Mock, because amazingly you can't use it to verify
      # that block arguments are passed.
      scope = HookTester.new
      subject.run(scope, &expected_block)

      # ... and must_equal is blowing up inside minitest when dealing with
      # blocks.
      assert_equal(expected_block, scope.passed_block)
    end

    it "passes the block as a Proc when given a block hook" do
      expected_block = Proc.new { true }
      passed_block = nil

      subject << lambda { |passed| passed_block = passed }
      subject.run(Object.new, &expected_block)

      assert_equal(expected_block, passed_block)
    end

    it "passes the block to the method when given a hook object" do
      expected_block = Proc.new { true }
      hook_tester = HookTester.new

      subject << hook_tester
      subject.run(Object.new, &expected_block)

      assert_equal(expected_block, hook_tester.passed_block)
    end
  end

  describe "#run with :around set to true and a block passed" do
    subject { Hooks::Hook.new({:name => :test_hook, :around => true}) }

    it "raises if no block is passed" do
      lambda do
        subject.run(Object.new)
      end.must_raise(ArgumentError)
    end

    it "doesn't call the block if an intermediate callback fails to yield" do
      called = false

      subject << lambda { |around| around.call }
      subject << lambda { |around| nil }
      subject << lambda { |around| around.call }

      subject.run(Object.new) do
        called = true
      end

      called.must_equal false
    end

    it "only calls the block once if all callbacks yield appropriately" do
      call_count = 0

      subject << lambda { |around| around.call }
      subject << HookTester.new
      subject << lambda { |around| around.call }

      subject.run(Object.new) do
        call_count += 1
      end

      call_count.must_equal 1
    end

    it "doesn't call the actual block until the very last callback runs" do
      called = false

      subject << lambda do |around|
        called.must_equal false
        around.call
        called.must_equal false
      end

      subject << HookTester.new

      subject << lambda do |around|
        called.must_equal false
        around.call
        called.must_equal true
      end

      subject.run(Object.new) do
        called = true
      end
    end

    it "calls the block if no callbacks are set up" do
      called = false

      subject.run(Object.new) do
        called = true
      end

      called.must_equal true
    end
  end
end

class ResultsTest < MiniTest::Spec
  subject { Hooks::Hook::Results.new }

  describe "#halted?" do
    it "defaults to false" do
      subject.halted?.must_equal false
    end

    it "responds to #halted!" do
      subject.halted!
      subject.halted?.must_equal true
    end

    it "responds to #not_halted?" do
      subject.not_halted?.must_equal true
    end
  end
end
