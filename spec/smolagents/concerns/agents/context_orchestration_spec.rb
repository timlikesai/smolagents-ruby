require "spec_helper"
require "smolagents/concerns/agents/context_orchestration"

RSpec.describe Smolagents::Concerns::ContextOrchestration do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::GoalTracking
      include Smolagents::Concerns::WorkingMemory
      include Smolagents::Concerns::StepContext
      include Smolagents::Concerns::ContextOrchestration

      attr_accessor :max_steps, :ctx, :executor, :planning_interval, :plan_context, :memory
      attr_accessor :reflection_config, :reflection_store

      def initialize
        @max_steps = 10
        @ctx = Data.define(:step_number).new(step_number: 2)
        @executor = mock_executor
        @planning_interval = nil
        @plan_context = nil
        @memory = mock_memory
        @reflection_config = nil
        @reflection_store = nil
        initialize_goal_tracking
        initialize_working_memory
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

    it "always registers planning provider" do
      instance.send(:initialize_context_orchestration)
      providers = instance.context_orchestrator.providers
      expect(providers.map(&:context_key)).to include(:planning)
    end

    it "planning provider returns nil when planning_interval is nil" do
      instance.send(:initialize_context_orchestration)
      provider = instance.context_orchestrator.providers.find { |p| p.context_key == :planning }
      expect(provider.context_contribution(budget: 100)).to be_nil
    end

    it "planning provider returns content when planning_interval is set" do
      plan_ctx = Object.new
      plan_ctx.define_singleton_method(:initialized?) { true }
      plan_ctx.define_singleton_method(:plan) { "1. Do thing" }
      instance.planning_interval = 3
      instance.plan_context = plan_ctx
      instance.send(:initialize_context_orchestration)
      provider = instance.context_orchestrator.providers.find { |p| p.context_key == :planning }
      expect(provider.context_contribution(budget: 100)).to include("CURRENT PLAN")
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

  describe "integration with reflections" do
    # Reuse the main test_class which now includes all concerns
    let(:instance_with_reflections) { test_class.new }

    let(:reflection) do
      ref = Object.new
      ref.define_singleton_method(:to_context) { "Timeout error: reduce batch size" }
      ref
    end

    let(:reflection_store) do
      store = Object.new
      refs = [reflection]
      store.define_singleton_method(:relevant_to) { |_task, limit:| refs.take(limit) }
      store
    end

    let(:reflection_config) do
      cfg = Object.new
      cfg.define_singleton_method(:enabled) { true }
      cfg
    end

    it "always registers reflection provider" do
      instance_with_reflections.send(:initialize_context_orchestration)
      providers = instance_with_reflections.context_orchestrator.providers
      expect(providers.map(&:context_key)).to include(:reflections)
    end

    it "reflection provider returns nil when config is nil" do
      instance_with_reflections.send(:initialize_context_orchestration)
      provider = instance_with_reflections.context_orchestrator.providers.find { |p| p.context_key == :reflections }
      expect(provider.context_contribution(budget: 100)).to be_nil
    end

    it "reflection provider returns nil when config is disabled" do
      disabled_cfg = Object.new
      disabled_cfg.define_singleton_method(:enabled) { false }
      instance_with_reflections.reflection_config = disabled_cfg
      instance_with_reflections.send(:initialize_context_orchestration)

      provider = instance_with_reflections.context_orchestrator.providers.find { |p| p.context_key == :reflections }
      expect(provider.context_contribution(budget: 100)).to be_nil
    end

    it "reflection provider returns content when enabled" do
      instance_with_reflections.reflection_config = reflection_config
      instance_with_reflections.reflection_store = reflection_store
      instance_with_reflections.send(:initialize_context_orchestration)

      provider = instance_with_reflections.context_orchestrator.providers.find { |p| p.context_key == :reflections }
      expect(provider.context_contribution(budget: 100)).to include("Lessons from Previous Attempts")
    end

    it "includes reflection content in assembly" do
      instance_with_reflections.reflection_config = reflection_config
      instance_with_reflections.reflection_store = reflection_store
      instance_with_reflections.send(:initialize_context_orchestration)

      result = instance_with_reflections.send(:assemble_context)
      expect(result.content).to include("Lessons from Previous Attempts")
      expect(result.content).to include("Timeout error")
    end
  end

  describe "provider priority ordering" do
    let(:plan_context) do
      ctx = Object.new
      ctx.define_singleton_method(:initialized?) { true }
      ctx.define_singleton_method(:plan) { "1. Step one" }
      ctx
    end

    it "includes providers in priority order" do
      instance.planning_interval = 3
      instance.plan_context = plan_context
      instance.send(:initialize_context_orchestration)

      result = instance.send(:assemble_context)
      providers = result.metadata[:providers_included]

      # step_context (priority 90) should be included before planning (priority 80)
      expect(providers).to include(:step_context, :planning)
    end
  end

  describe "full message assembly" do
    let(:plan_context) do
      ctx = Object.new
      ctx.define_singleton_method(:initialized?) { true }
      ctx.define_singleton_method(:plan) { "1. Find info" }
      ctx
    end

    let(:messages) do
      [
        Smolagents::Types::ChatMessage.system("You are a helpful agent"),
        Smolagents::Types::ChatMessage.user("Search for Ruby news")
      ]
    end

    it "injects all enabled context into messages" do
      instance.planning_interval = 3
      instance.plan_context = plan_context
      instance.send(:initialize_context_orchestration)

      result = instance.send(:inject_orchestrated_context, messages)

      # Should have: system, context (with step + plan), user
      expect(result.size).to eq(3)

      # Context message should contain both step and plan info
      context_msg = result[1]
      expect(context_msg.role).to eq(:system)
      expect(context_msg.content).to include("Step:")
      expect(context_msg.content).to include("CURRENT PLAN:")
    end
  end
end
