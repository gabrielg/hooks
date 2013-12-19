require 'test_helper'

class HookTest < MiniTest::Spec
  subject { Hooks::Hook.new({:name => :test_hook}) }

  it "exposes array behaviour for callbacks" do
    subject << :play_music
    subject << :drink_beer

    subject.to_a.must_equal [:play_music, :drink_beer]
  end

  describe "#run" do
    it "executes the same-named method when given a symbol" do
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

      # hook_object.expect(:kind_of?, false, [Symbol])
      # hook_object.expect(:kind_of?, false, [Proc])
      hook_object.expect(:test_hook, nil, [scope, :another_arg])

      subject.run(scope, :another_arg)

      hook_object.verify
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
