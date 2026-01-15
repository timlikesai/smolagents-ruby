require "spec_helper"

RSpec.describe "Fiber-based agent execution" do
  # Mock agent class that includes the ReAct loop
  let(:agent_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop

      attr_writer :step_responses

      def initialize(max_steps: 5)
        @max_steps = max_steps
        @memory = Smolagents::Runtime::AgentMemory.new("You are a test agent.")
        @tools = {}
        @logger = Logger.new(nil)
        @state = {}
        @step_responses = []
        @step_index = 0
      end

      def step(_task, step_number:)
        response = @step_responses[@step_index] || default_step(step_number)
        @step_index += 1
        response
      end

      def finalize(state, output, _context)
        Smolagents::Types::RunResult.new(
          output:,
          state:,
          steps: @memory.steps,
          token_usage: Smolagents::Types::TokenUsage.new(input_tokens: 0, output_tokens: 0),
          timing: Smolagents::Types::Timing.new(start_time: Time.now, end_time: Time.now)
        )
      end

      def finalize_error(_error, _context = nil)
        Smolagents::Types::RunResult.new(
          output: nil,
          state: :error,
          steps: @memory.steps,
          token_usage: Smolagents::Types::TokenUsage.new(input_tokens: 0, output_tokens: 0),
          timing: Smolagents::Types::Timing.new(start_time: Time.now, end_time: Time.now)
        )
      end

      private

      def default_step(step_number)
        Smolagents::Types::ActionStep.new(
          step_number:,
          timing: Smolagents::Types::Timing.new(start_time: Time.now, end_time: Time.now),
          tool_calls: [],
          error: nil,
          model_output_message: nil,
          code_action: nil,
          observations: "Observation #{step_number}",
          action_output: step_number >= 3 ? "Final answer" : nil,
          token_usage: nil,
          is_final_answer: step_number >= 3
        )
      end

      def emit_step_completed_event(_step); end
      def emit_task_completed_event(*_args); end
      def emit(*_args); end

      def execute_step_with_monitoring(task, context)
        step_number = context.step_number
        [step(task, step_number:), context]
      end

      def prepare_task(_task, **_kwargs); end
      def reset_state; end
    end
  end

  let(:agent) { agent_class.new(max_steps: 5) }

  describe "#run_fiber" do
    it "returns a Fiber" do
      fiber = agent.run_fiber("test task")
      expect(fiber).to be_a(Fiber)
    end

    it "yields ActionSteps during execution" do
      fiber = agent.run_fiber("test task")
      steps = []

      loop do
        result = fiber.resume
        case result
        when Smolagents::Types::ActionStep
          steps << result
        when Smolagents::Types::RunResult
          break
        end
      end

      expect(steps.size).to be >= 1
      expect(steps.first).to be_a(Smolagents::Types::ActionStep)
    end

    it "yields RunResult when complete" do
      fiber = agent.run_fiber("test task")
      final_result = nil

      loop do
        result = fiber.resume
        case result
        when Smolagents::Types::RunResult
          final_result = result
          break
        end
      end

      expect(final_result).to be_a(Smolagents::Types::RunResult)
      expect(final_result.output).to eq("Final answer")
    end

    it "respects max_steps limit" do
      never_final_agent = agent_class.new(max_steps: 2)
      never_final_agent.step_responses = [
        Smolagents::Types::ActionStep.new(
          step_number: 1, is_final_answer: false,
          timing: Smolagents::Types::Timing.new(start_time: Time.now, end_time: Time.now),
          tool_calls: [], error: nil, model_output_message: nil,
          code_action: nil, observations: "O1", action_output: nil, token_usage: nil
        ),
        Smolagents::Types::ActionStep.new(
          step_number: 2, is_final_answer: false,
          timing: Smolagents::Types::Timing.new(start_time: Time.now, end_time: Time.now),
          tool_calls: [], error: nil, model_output_message: nil,
          code_action: nil, observations: "O2", action_output: nil, token_usage: nil
        )
      ]

      fiber = never_final_agent.run_fiber("test task")
      step_count = 0
      final_result = nil

      loop do
        result = fiber.resume
        case result
        when Smolagents::Types::ActionStep
          step_count += 1
        when Smolagents::Types::RunResult
          final_result = result
          break
        end
      end

      expect(step_count).to eq(2)
      expect(final_result.state).to eq(:max_steps_reached)
    end
  end

  describe "#fiber_context?" do
    it "returns false outside Fiber context" do
      Thread.current[:smolagents_fiber_context] = nil
      expect(agent.fiber_context?).to be false
    end

    it "returns true when thread-local is set (inside run_fiber)" do
      # fiber_context? uses thread-local variable set by fiber_loop
      Thread.current[:smolagents_fiber_context] = true
      expect(agent.fiber_context?).to be true
    ensure
      Thread.current[:smolagents_fiber_context] = nil
    end
  end

  describe "Control concern" do
    describe "#request_input" do
      it "raises ControlFlowError outside Fiber context" do
        expect { agent.request_input("test") }.to raise_error(Smolagents::ControlFlowError)
      end
    end

    describe "#request_confirmation" do
      it "raises ControlFlowError outside Fiber context" do
        expect do
          agent.request_confirmation(action: "test", description: "test")
        end.to raise_error(Smolagents::ControlFlowError)
      end
    end

    describe "#escalate_query" do
      it "raises ControlFlowError outside Fiber context" do
        expect { agent.escalate_query("test") }.to raise_error(Smolagents::ControlFlowError)
      end
    end
  end
end

RSpec.describe "Control Events" do
  describe Smolagents::Events::ControlYielded do
    it "can be created with the DSL" do
      event = described_class.create(
        request_type: :user_input,
        request_id: "abc",
        prompt: "What file?"
      )

      expect(event.request_type).to eq(:user_input)
      expect(event.request_id).to eq("abc")
      expect(event.prompt).to eq("What file?")
      expect(event.id).to be_a(String)
      expect(event.created_at).to be_a(Time)
    end

    it "has predicates" do
      event = described_class.create(request_type: :user_input, request_id: "abc", prompt: "test")
      expect(event).to respond_to(:user_input?)
      expect(event).to respond_to(:confirmation?)
      expect(event).to respond_to(:sub_agent_query?)
    end
  end

  describe Smolagents::Events::ControlResumed do
    it "can be created with the DSL" do
      event = described_class.create(
        request_id: "abc",
        approved: true,
        value: "config.yml"
      )

      expect(event.request_id).to eq("abc")
      expect(event.approved).to be true
      expect(event.value).to eq("config.yml")
    end

    it "defaults value to nil" do
      event = described_class.create(request_id: "abc", approved: false)
      expect(event.value).to be_nil
    end
  end
end
