require "smolagents"

RSpec.describe Smolagents::Concerns::ReflectionMemory do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::ReflectionMemory

      attr_accessor :logger

      def initialize(reflection_config: nil)
        @logger = Smolagents::AgentLogger.new(output: StringIO.new, level: Smolagents::AgentLogger::DEBUG)
        initialize_reflection_memory(reflection_config:)
      end
    end
  end

  describe Smolagents::Types::ReflectionConfig do
    describe ".default" do
      it "creates enabled config" do
        config = described_class.default
        expect(config.enabled).to be(true)
        expect(config.max_reflections).to eq(10)
        expect(config.include_successful).to be(false)
      end
    end

    describe ".disabled" do
      it "creates disabled config" do
        config = described_class.disabled
        expect(config.enabled).to be(false)
      end
    end
  end

  describe Smolagents::Types::Reflection do
    describe ".from_failure" do
      let(:step) do
        Smolagents::ActionStep.new(
          step_number: 1,
          error: "undefined local variable `x'",
          tool_calls: [Smolagents::ToolCall.new(name: "search", arguments: { query: "test" }, id: "1")]
        )
      end

      it "creates failure reflection" do
        reflection = described_class.from_failure(
          task: "find something",
          step:,
          reflection_text: "define x first"
        )
        expect(reflection.failure?).to be(true)
        expect(reflection.outcome).to eq(:failure)
        expect(reflection.observation).to include("undefined")
        expect(reflection.action).to include("search")
      end
    end

    describe ".from_success" do
      let(:step) do
        Smolagents::ActionStep.new(
          step_number: 1,
          action_output: "42",
          code_action: "result = 6 * 7"
        )
      end

      it "creates success reflection" do
        reflection = described_class.from_success(
          task: "compute",
          step:,
          reflection_text: "multiplication works"
        )
        expect(reflection.success?).to be(true)
        expect(reflection.outcome).to eq(:success)
      end
    end

    describe "#to_context" do
      it "formats for injection" do
        reflection = described_class.new(
          task: "test task",
          action: "search(query)",
          outcome: :failure,
          observation: "not found",
          reflection: "try different query",
          timestamp: Time.now
        )
        context = reflection.to_context
        expect(context).to include("Previous attempt")
        expect(context).to include("search(query)")
        expect(context).to include("failure")
        expect(context).to include("Lesson:")
      end
    end
  end

  describe Smolagents::Concerns::ReflectionMemory::Store do
    let(:store) { described_class.new(max_size: 3) }

    describe "#add" do
      it "stores reflections" do
        reflection = Smolagents::Types::Reflection.new(
          task: "t", action: "a", outcome: :failure,
          observation: "o", reflection: "r", timestamp: Time.now
        )
        store.add(reflection)
        expect(store.size).to eq(1)
      end

      it "evicts oldest when at capacity" do
        3.times do |i|
          store.add(Smolagents::Types::Reflection.new(
                      task: "task#{i}", action: "a", outcome: :failure,
                      observation: "o", reflection: "r", timestamp: Time.now
                    ))
        end
        expect(store.size).to eq(3)

        store.add(Smolagents::Types::Reflection.new(
                    task: "task_new", action: "a", outcome: :failure,
                    observation: "o", reflection: "r", timestamp: Time.now
                  ))
        expect(store.size).to eq(3)
        expect(store.all.map(&:task)).not_to include("task0")
        expect(store.all.map(&:task)).to include("task_new")
      end
    end

    describe "#relevant_to" do
      before do
        store.add(Smolagents::Types::Reflection.new(
                    task: "search for ruby docs", action: "search", outcome: :failure,
                    observation: "timeout", reflection: "use cache", timestamp: Time.now - 100
                  ))
        store.add(Smolagents::Types::Reflection.new(
                    task: "find python tutorial", action: "web", outcome: :failure,
                    observation: "error", reflection: "check url", timestamp: Time.now - 50
                  ))
        store.add(Smolagents::Types::Reflection.new(
                    task: "search for ruby gems", action: "search", outcome: :failure,
                    observation: "rate limit", reflection: "wait", timestamp: Time.now
                  ))
      end

      it "returns failures relevant to task" do
        relevant = store.relevant_to("search for ruby version", limit: 2)
        expect(relevant.size).to eq(2)
        # Should prefer tasks with "ruby" and "search"
        expect(relevant.map(&:task)).to all(include("ruby").or(include("search")))
      end

      it "respects limit" do
        relevant = store.relevant_to("anything", limit: 1)
        expect(relevant.size).to eq(1)
      end
    end

    describe "#failures" do
      it "returns only failures" do
        store.add(Smolagents::Types::Reflection.new(
                    task: "t1", action: "a", outcome: :failure,
                    observation: "o", reflection: "r", timestamp: Time.now
                  ))
        store.add(Smolagents::Types::Reflection.new(
                    task: "t2", action: "a", outcome: :success,
                    observation: "o", reflection: "r", timestamp: Time.now
                  ))
        expect(store.failures.size).to eq(1)
        expect(store.failures.first.task).to eq("t1")
      end
    end

    describe "#clear" do
      it "removes all reflections" do
        store.add(Smolagents::Types::Reflection.new(
                    task: "t", action: "a", outcome: :failure,
                    observation: "o", reflection: "r", timestamp: Time.now
                  ))
        store.clear
        expect(store.size).to eq(0)
      end
    end
  end

  describe "#initialize_reflection_memory" do
    it "defaults to disabled" do
      agent = test_class.new
      expect(agent.reflection_config.enabled).to be(false)
    end

    it "uses provided config" do
      config = Smolagents::Types::ReflectionConfig.default
      agent = test_class.new(reflection_config: config)
      expect(agent.reflection_config.enabled).to be(true)
    end

    it "creates reflection store" do
      config = Smolagents::Types::ReflectionConfig.default
      agent = test_class.new(reflection_config: config)
      expect(agent.reflection_store).to be_a(Smolagents::Concerns::ReflectionMemory::Store)
    end
  end

  describe "#record_reflection" do
    let(:config) { Smolagents::Types::ReflectionConfig.default }
    let(:agent) { test_class.new(reflection_config: config) }

    context "when step has error" do
      let(:step) do
        Smolagents::ActionStep.new(
          step_number: 1,
          error: "undefined local variable or method `foo'",
          code_action: "result = foo + 1"
        )
      end

      it "records failure reflection" do
        reflection = agent.send(:record_reflection, step, "compute result")
        expect(reflection).to be_a(Smolagents::Types::Reflection)
        expect(reflection.failure?).to be(true)
        expect(agent.reflection_store.size).to eq(1)
      end

      it "generates actionable reflection text" do
        reflection = agent.send(:record_reflection, step, "compute result")
        expect(reflection.reflection).to include("Define")
        expect(reflection.reflection).to include("foo")
      end
    end

    context "when step is successful" do
      let(:step) do
        Smolagents::ActionStep.new(
          step_number: 1,
          action_output: "42"
        )
      end

      it "returns nil by default" do
        reflection = agent.send(:record_reflection, step, "compute result")
        expect(reflection).to be_nil
      end

      context "with include_successful enabled" do
        let(:config) do
          Smolagents::Types::ReflectionConfig.new(
            max_reflections: 10, enabled: true, include_successful: true
          )
        end
        let(:agent) { test_class.new(reflection_config: config) }

        it "records success reflection" do
          reflection = agent.send(:record_reflection, step, "compute result")
          expect(reflection.success?).to be(true)
        end
      end
    end

    context "when disabled" do
      let(:agent) { test_class.new }

      it "returns nil" do
        step = Smolagents::ActionStep.new(step_number: 1, error: "error")
        reflection = agent.send(:record_reflection, step, "task")
        expect(reflection).to be_nil
      end
    end

    context "when step is final answer" do
      let(:step) do
        Smolagents::ActionStep.new(step_number: 1, is_final_answer: true)
      end

      it "returns nil" do
        reflection = agent.send(:record_reflection, step, "task")
        expect(reflection).to be_nil
      end
    end
  end

  describe "#get_relevant_reflections" do
    let(:config) { Smolagents::Types::ReflectionConfig.default }
    let(:agent) { test_class.new(reflection_config: config) }

    before do
      # Add some reflections
      step = Smolagents::ActionStep.new(step_number: 1, error: "error", code_action: "x")
      agent.send(:record_reflection, step, "search for ruby docs")
      agent.send(:record_reflection, step, "find python tutorial")
    end

    it "returns relevant reflections" do
      reflections = agent.send(:get_relevant_reflections, "search for ruby gems")
      expect(reflections).not_to be_empty
    end

    it "respects limit" do
      reflections = agent.send(:get_relevant_reflections, "anything", limit: 1)
      expect(reflections.size).to be <= 1
    end
  end

  describe "#inject_reflections" do
    let(:config) { Smolagents::Types::ReflectionConfig.default }
    let(:agent) { test_class.new(reflection_config: config) }

    context "with no reflections" do
      it "returns task unchanged" do
        result = agent.send(:inject_reflections, "do something")
        expect(result).to eq("do something")
      end
    end

    context "with reflections" do
      before do
        step = Smolagents::ActionStep.new(step_number: 1, error: "error", code_action: "x")
        agent.send(:record_reflection, step, "do something")
      end

      it "prepends reflection context" do
        result = agent.send(:inject_reflections, "do something")
        expect(result).to include("Lessons from Previous Attempts")
        expect(result).to include("Current Task")
        expect(result).to include("do something")
      end
    end
  end

  describe "#infer_reflection_from_error" do
    let(:agent) { test_class.new(reflection_config: Smolagents::Types::ReflectionConfig.default) }
    let(:step) { Smolagents::ActionStep.new(step_number: 1) }

    it "handles undefined variable errors" do
      reflection = agent.send(:infer_reflection_from_error, "undefined local variable or method `foo'", step)
      expect(reflection).to include("Define")
      expect(reflection).to include("foo")
    end

    it "handles undefined method errors" do
      reflection = agent.send(:infer_reflection_from_error, "undefined method `bar'", step)
      expect(reflection).to include("bar")
      expect(reflection).to include("different approach")
    end

    it "handles argument errors" do
      reflection = agent.send(:infer_reflection_from_error, "wrong number of arguments (given 2, expected 1)", step)
      expect(reflection).to include("arguments")
    end

    it "handles type conversion errors" do
      reflection = agent.send(:infer_reflection_from_error, "no implicit conversion of Integer", step)
      expect(reflection).to include("conversion")
    end

    it "handles syntax errors" do
      reflection = agent.send(:infer_reflection_from_error, "syntax error, unexpected end", step)
      expect(reflection).to include("brackets")
    end

    it "handles tool not found errors" do
      reflection = agent.send(:infer_reflection_from_error, "Tool 'missing' not found", step)
      expect(reflection).to include("available tools")
    end

    it "handles timeout errors" do
      reflection = agent.send(:infer_reflection_from_error, "execution timed out", step)
      expect(reflection).to include("Simplify")
    end

    it "provides generic guidance for unknown errors" do
      reflection = agent.send(:infer_reflection_from_error, "something weird happened", step)
      expect(reflection).to include("different")
    end
  end

  describe "#format_reflections_for_context" do
    let(:agent) { test_class.new(reflection_config: Smolagents::Types::ReflectionConfig.default) }

    it "returns empty string for no reflections" do
      result = agent.send(:format_reflections_for_context, [])
      expect(result).to eq("")
    end

    it "formats multiple reflections" do
      reflections = [
        Smolagents::Types::Reflection.new(
          task: "t1", action: "a1", outcome: :failure,
          observation: "o1", reflection: "r1", timestamp: Time.now
        ),
        Smolagents::Types::Reflection.new(
          task: "t2", action: "a2", outcome: :failure,
          observation: "o2", reflection: "r2", timestamp: Time.now
        )
      ]
      result = agent.send(:format_reflections_for_context, reflections)
      expect(result).to include("Lessons from Previous Attempts")
      expect(result).to include("1.")
      expect(result).to include("2.")
    end
  end
end
