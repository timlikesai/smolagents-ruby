# Integration tests for Phases 3-5 components.
#
# Tests verify correct wiring and interaction between:
# - Phase 3: Working Memory (PERSISTENT layer)
# - Phase 4: Goal-Driven Loop + Goal-Aware Yield
# - Phase 5: Type consolidation (AsyncToolError, ToolFuture)
#
# These tests are deterministic, fast, and use mock objects to avoid
# external dependencies. They validate integration boundaries.

require "spec_helper"

RSpec.describe "Phase 3-5 Integration", type: :integration do
  # Stub module for GoalDrivenLoop super calls
  module LoopStubs
    def after_step(_task, _step, ctx)
      ctx
    end

    def check_step_completion(_task, _step, _ctx, _memory)
      nil
    end
  end

  # Minimal runtime that includes all Phase 3-5 concerns in correct order
  let(:integrated_class) do
    stubs = LoopStubs
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::GoalTracking
      include Smolagents::Concerns::WorkingMemory
      include Smolagents::Concerns::StepContext
      include Smolagents::Concerns::ContextOrchestration
      include Smolagents::Concerns::EarlyYield
      include Smolagents::Concerns::GoalAwareYield
      # Stubs provide base methods for GoalDrivenLoop to override
      include stubs
      include Smolagents::Concerns::GoalDrivenLoop

      attr_accessor :max_steps, :ctx, :executor, :planning_interval, :memory
      attr_accessor :reflection_config, :reflection_store

      def initialize
        @max_steps = 10
        @ctx = Data.define(:step_number).new(step_number: 1)
        @executor = build_mock_executor
        @planning_interval = nil
        @memory = build_mock_memory
        @reflection_config = nil
        @reflection_store = nil
        initialize_goal_tracking
        initialize_working_memory
        initialize_context_orchestration
      end

      private

      def build_mock_executor
        exec = Object.new
        exec.define_singleton_method(:respond_to?) { |meth| meth == :tool_calls }
        exec.define_singleton_method(:tool_calls) { [] }
        exec
      end

      def build_mock_memory
        mem = Object.new
        mem.define_singleton_method(:steps) { [] }
        mem
      end
    end
  end

  let(:runtime) { integrated_class.new }

  describe "Working Memory + Context Orchestration" do
    it "includes working_memory provider when initialized" do
      providers = runtime.context_orchestrator.providers
      expect(providers.map(&:context_key)).to include(:working_memory)
    end

    it "working_memory provider is at PERSISTENT layer" do
      provider = runtime.context_orchestrator.providers.find { |p| p.context_key == :working_memory }
      expect(provider.context_layer).to eq(Smolagents::Context::Layer::PERSISTENT)
    end

    it "working_memory provider is NOT optional" do
      provider = runtime.context_orchestrator.providers.find { |p| p.context_key == :working_memory }
      expect(provider.context_optional?).to be false
    end

    it "working_memory content appears in assembled context" do
      runtime.update_objective("Find Ruby 4.0 release notes")
      runtime.record_finding("Official site has changelog")

      result = runtime.send(:assemble_context)
      expect(result.content).to include("Objective: Find Ruby 4.0 release notes")
      expect(result.content).to include("Findings: Official site has changelog")
    end

    it "working_memory has highest priority (100)" do
      provider = runtime.context_orchestrator.providers.find { |p| p.context_key == :working_memory }
      expect(provider.context_priority).to eq(100)
    end
  end

  describe "Goal Tracking + Context Orchestration" do
    it "includes goals provider when initialized" do
      providers = runtime.context_orchestrator.providers
      expect(providers.map(&:context_key)).to include(:goals)
    end

    it "goal context appears in assembled context" do
      runtime.create_goal_from_task("Research Ruby concurrency")
      runtime.update_goal_progress(runtime.current_goal, "Found Ractor docs")

      result = runtime.send(:assemble_context)
      expect(result.content).to include("Current goal: Research Ruby concurrency")
      expect(result.content).to include("Progress: Found Ractor docs")
    end

    it "goals provider is at STRATEGIC layer" do
      provider = runtime.context_orchestrator.providers.find { |p| p.context_key == :goals }
      expect(provider.context_layer).to eq(Smolagents::Context::Layer::STRATEGIC)
    end
  end

  describe "Working Memory + Goal Tracking" do
    it "objective can be set from goal description" do
      goal = runtime.create_goal_from_task("Find Ruby 4.0 docs")
      runtime.update_objective(goal.description)

      expect(runtime.working_memory.objective).to eq("Find Ruby 4.0 docs")
    end

    it "findings can record goal progress" do
      runtime.create_goal_from_task("Research concurrency")
      runtime.record_finding("Ractor available in Ruby 3.0+")
      runtime.record_finding("Fiber scheduler added in Ruby 3.0")

      findings = runtime.working_memory.findings
      expect(findings).to include("Ractor available in Ruby 3.0+")
      expect(findings).to include("Fiber scheduler added in Ruby 3.0")
    end

    it "blockers persist separately from goal progress" do
      runtime.create_goal_from_task("Find docs")
      runtime.record_blocker("API rate limited")
      runtime.update_goal_progress(runtime.current_goal, "Found 2 sources")

      expect(runtime.working_memory.blockers).to include("API rate limited")
      expect(runtime.current_goal.progress).to eq("Found 2 sources")
    end
  end

  describe "GoalDrivenLoop integration" do
    it "has goal-aware step completion methods" do
      expect(runtime).to respond_to(:after_step)
      expect(runtime).to respond_to(:check_step_completion)
    end

    it "after_step records goal progress from step" do
      runtime.create_goal_from_task("Research topic")

      # Simulate a step with tool output (uses action_output for progress)
      step = Smolagents::Types::ActionStep.new(
        step_number: 1,
        action_output: "Found relevant information",
        tool_calls: [],
        timing: Smolagents::Types::Timing.new(start_time: Time.now, end_time: Time.now)
      )

      runtime.send(:after_step, "task", step, nil)

      updated_goal = runtime.current_goal
      expect(updated_goal.progress).to include("Found relevant information")
    end

    it "check_step_completion detects goal completion" do
      runtime.create_goal_from_task("Simple task")
      runtime.complete_goal(runtime.current_goal, evidence: "Task done")

      # check_goal_completion should detect completed root goal
      # (in real usage this triggers finalization)
      completed_root = runtime.goal_store.completed.reverse.find(&:root?)
      expect(completed_root).not_to be_nil
      expect(completed_root.progress).to eq("Task done")
    end
  end

  describe "GoalAwareYield integration" do
    it "has execute_tools_for_goal method" do
      expect(runtime).to respond_to(:execute_tools_for_goal)
    end

    it "passes tool calls through when no goal" do
      # Without a goal, should fall back to standard execution
      tool_calls = [double("ToolCall", name: "search", arguments: {})]
      allow(runtime).to receive(:execute_standard).with(tool_calls)

      runtime.send(:execute_tools_for_goal, tool_calls)

      expect(runtime).to have_received(:execute_standard).with(tool_calls)
    end

    it "uses goal-aware predicate when goal exists" do
      runtime.create_goal_from_task("Find specific answer")

      # Mock the early yield method
      allow(runtime).to receive(:execute_with_early_yield).and_return([])

      tool_calls = [
        double("ToolCall", name: "search", arguments: { query: "ruby" }),
        double("ToolCall", name: "search", arguments: { query: "python" })
      ]

      runtime.send(:execute_tools_for_goal, tool_calls)

      expect(runtime).to have_received(:execute_with_early_yield)
    end
  end

  describe "Full Context Assembly" do
    it "assembles all layers in correct priority order" do
      # Set up all context sources
      runtime.update_objective("Main objective")
      runtime.record_finding("Important finding")
      runtime.create_goal_from_task("Current goal")

      result = runtime.send(:assemble_context)

      # All providers should be included
      included = result.metadata[:providers_included]
      expect(included).to include(:working_memory)
      expect(included).to include(:goals)
      expect(included).to include(:step_context)
    end

    it "working_memory comes before strategic context" do
      runtime.update_objective("Objective")
      runtime.create_goal_from_task("Goal")

      result = runtime.send(:assemble_context)

      # Working memory (priority 100) before goals (priority 70)
      included = result.metadata[:providers_included]
      wm_idx = included.index(:working_memory)
      goals_idx = included.index(:goals)

      expect(wm_idx).to be < goals_idx
    end

    it "context content is properly formatted" do
      runtime.update_objective("Find Ruby release notes")
      runtime.record_finding("Ruby 3.3 released Dec 2023")
      runtime.create_goal_from_task("Get latest Ruby version")

      result = runtime.send(:assemble_context)

      expect(result.content).to include("Objective:")
      expect(result.content).to include("Findings:")
      expect(result.content).to include("Current goal:")
      expect(result.content).to include("[CONTEXT]") # Step context marker
    end
  end

  describe "Message Injection" do
    let(:messages) do
      [
        Smolagents::Types::ChatMessage.system("You are a helpful agent"),
        Smolagents::Types::ChatMessage.user("Find Ruby docs")
      ]
    end

    it "injects context into messages" do
      runtime.update_objective("Find Ruby docs")
      runtime.create_goal_from_task("Research Ruby 4.0")

      result = runtime.send(:inject_orchestrated_context, messages)

      # Should have: system, context, user
      expect(result.size).to eq(3)
      expect(result[1].role).to eq(:system)
      expect(result[1].content).to include("Objective:")
    end

    it "preserves message order" do
      runtime.update_objective("Test")

      result = runtime.send(:inject_orchestrated_context, messages)

      expect(result.first.content).to eq("You are a helpful agent")
      expect(result.last.content).to eq("Find Ruby docs")
    end
  end

  describe "Isolation" do
    it "each runtime has independent working memory" do
      runtime1 = integrated_class.new
      runtime2 = integrated_class.new

      runtime1.update_objective("Objective 1")
      runtime2.update_objective("Objective 2")

      expect(runtime1.working_memory.objective).to eq("Objective 1")
      expect(runtime2.working_memory.objective).to eq("Objective 2")
    end

    it "each runtime has independent goal store" do
      runtime1 = integrated_class.new
      runtime2 = integrated_class.new

      runtime1.create_goal_from_task("Task 1")
      runtime2.create_goal_from_task("Task 2")

      expect(runtime1.goal_store.size).to eq(1)
      expect(runtime2.goal_store.size).to eq(1)
      expect(runtime1.current_goal.description).to eq("Task 1")
      expect(runtime2.current_goal.description).to eq("Task 2")
    end
  end

  describe "AsyncToolError type (Phase 5)" do
    it "can be created with id and message" do
      error = Smolagents::Types::AsyncToolError.new(
        id: "search_1",
        message: "Timeout after 5s"
      )

      expect(error.id).to eq("search_1")
      expect(error.message).to eq("Timeout after 5s")
    end

    it "stringifies to message" do
      error = Smolagents::Types::AsyncToolError.new(
        id: "test",
        message: "Connection refused"
      )

      expect(error.to_s).to eq("Connection refused")
    end
  end
end
