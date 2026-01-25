require "smolagents/concerns/agents/react_loop/core"

RSpec.describe Smolagents::Concerns::ReActLoop::Core do
  describe ".included" do
    let(:test_class) { Class.new }

    before do
      test_class.include(described_class)
    end

    it "includes Setup module" do
      expect(test_class.included_modules).to include(Smolagents::Concerns::ReActLoop::Setup)
    end

    it "includes RunEntry module" do
      expect(test_class.included_modules).to include(Smolagents::Concerns::ReActLoop::RunEntry)
    end

    it "includes FiberExecution module" do
      expect(test_class.included_modules).to include(Smolagents::Concerns::ReActLoop::FiberExecution)
    end

    it "includes FiberConsumption module" do
      expect(test_class.included_modules).to include(Smolagents::Concerns::ReActLoop::FiberConsumption)
    end
  end

  describe "composition" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ReActLoop::Core
      end
    end

    it "provides setup functionality through Setup" do
      expect(test_class.new).to respond_to(:setup_agent)
    end

    it "provides run entry through RunEntry" do
      expect(test_class.new).to respond_to(:run)
    end

    it "provides fiber execution through FiberExecution" do
      expect(test_class.new).to respond_to(:run_fiber)
    end

    it "provides fiber consumption through FiberConsumption" do
      # consume_fiber is a private method
      expect(test_class.private_instance_methods).to include(:consume_fiber)
    end
  end

  describe "lifecycle integration" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ReActLoop::Core

        attr_accessor :model, :tools, :max_steps, :logger
      end
    end

    it "allows setup -> run flow" do
      instance = test_class.new
      expect(instance).to respond_to(:setup_agent)
      expect(instance).to respond_to(:run)
    end

    it "allows setup -> run_fiber flow" do
      instance = test_class.new
      expect(instance).to respond_to(:setup_agent)
      expect(instance).to respond_to(:run_fiber)
    end
  end

  describe "documentation" do
    it "defines Core as a module" do
      expect(described_class).to be_a(Module)
    end

    it "includes all required sub-modules" do
      test_class = Class.new
      test_class.include(described_class)

      required_modules = [
        Smolagents::Concerns::ReActLoop::Setup,
        Smolagents::Concerns::ReActLoop::RunEntry,
        Smolagents::Concerns::ReActLoop::FiberExecution,
        Smolagents::Concerns::ReActLoop::FiberConsumption
      ]

      required_modules.each do |mod|
        expect(test_class.included_modules).to include(mod)
      end
    end
  end
end
