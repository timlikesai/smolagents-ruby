require "spec_helper"
require "smolagents/concerns/agents/context_orchestration"

RSpec.describe Smolagents::Concerns::ContextOrchestration do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ContextOrchestration
      include Smolagents::Concerns::StepContext

      attr_accessor :max_steps, :ctx, :executor, :planning_interval, :plan_context, :memory

      def initialize
        @max_steps = 10
        @ctx = Data.define(:step_number).new(step_number: 2)
        @executor = mock_executor
        @planning_interval = nil
        @plan_context = nil
        @memory = mock_memory
      end

      def mock_executor
        exec = Object.new
        exec.define_singleton_method(:respond_to?) { |m| m == :tool_calls }
        exec.define_singleton_method(:tool_calls) { [] }
        exec
      end

      def mock_memory
        mem = Object.new
        mem.define_singleton_method(:steps) { [] }
        mem
      end
    end
  end

  let(:instance) { test_class.new }

  describe "#initialize_context_orchestration" do
    it "creates a context_orchestrator" do
      instance.send(:initialize_context_orchestration)
      expect(instance.context_orchestrator).to be_a(Smolagents::Context::Orchestrator)
    end

    it "includes step_context provider" do
      instance.send(:initialize_context_orchestration)
      providers = instance.context_orchestrator.providers
      expect(providers.map(&:context_key)).to include(:step_context)
    end

    it "excludes planning provider when planning_interval is nil" do
      instance.send(:initialize_context_orchestration)
      providers = instance.context_orchestrator.providers
      expect(providers.map(&:context_key)).not_to include(:planning)
    end

    it "includes planning provider when planning_interval is set" do
      instance.planning_interval = 3
      instance.send(:initialize_context_orchestration)
      providers = instance.context_orchestrator.providers
      expect(providers.map(&:context_key)).to include(:planning)
    end
  end

  describe "#assemble_context" do
    before { instance.send(:initialize_context_orchestration) }

    it "returns an AssemblyResult" do
      result = instance.send(:assemble_context)
      expect(result).to be_a(Smolagents::Context::AssemblyResult)
    end

    it "includes step context in content" do
      result = instance.send(:assemble_context)
      expect(result.content).to include("[CONTEXT]")
      expect(result.content).to include("Step: 3 of 10")
    end

    it "includes metadata" do
      result = instance.send(:assemble_context)
      expect(result.metadata[:providers_included]).to include(:step_context)
    end
  end

  describe "#inject_orchestrated_context" do
    before { instance.send(:initialize_context_orchestration) }

    let(:messages) do
      [
        Smolagents::Types::ChatMessage.system("System prompt"),
        Smolagents::Types::ChatMessage.user("Do something")
      ]
    end

    it "injects context before last user message" do
      result = instance.send(:inject_orchestrated_context, messages)
      expect(result.size).to eq(3)
      expect(result[1].role).to eq(:system)
      expect(result[1].content).to include("[CONTEXT]")
      expect(result[2].role).to eq(:user)
    end

    it "preserves original messages" do
      result = instance.send(:inject_orchestrated_context, messages)
      expect(result.first.content).to eq("System prompt")
      expect(result.last.content).to eq("Do something")
    end

    it "returns original messages when context is empty" do
      # Create instance with no context sources
      bare = test_class.new
      bare.max_steps = nil
      bare.ctx = nil
      bare.send(:initialize_context_orchestration)

      result = bare.send(:inject_orchestrated_context, messages)
      expect(result).to eq(messages)
    end
  end

  describe "#current_task_description" do
    it "returns empty string when no task step" do
      expect(instance.send(:current_task_description)).to eq("")
    end

    it "extracts task from TaskStep in memory" do
      task_step = Smolagents::Types::TaskStep.new(task: "Find Ruby info")
      mem = Object.new
      mem.define_singleton_method(:steps) { [task_step] }
      instance.memory = mem

      expect(instance.send(:current_task_description)).to eq("Find Ruby info")
    end
  end

  describe "integration with planning" do
    let(:plan_context) do
      ctx = Object.new
      ctx.define_singleton_method(:initialized?) { true }
      ctx.define_singleton_method(:plan) { "1. Search\n2. Summarize" }
      ctx
    end

    it "includes plan content when planning enabled" do
      instance.planning_interval = 3
      instance.plan_context = plan_context
      instance.send(:initialize_context_orchestration)

      result = instance.send(:assemble_context)
      expect(result.content).to include("CURRENT PLAN:")
      expect(result.content).to include("1. Search")
    end
  end
end
