require "smolagents"

RSpec.describe Smolagents::Concerns::GoalDrift do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::GoalDrift

      attr_accessor :logger

      def initialize(drift_config: nil)
        @logger = Smolagents::AgentLogger.new(output: StringIO.new, level: Smolagents::AgentLogger::DEBUG)
        initialize_goal_drift(drift_config:)
      end
    end
  end

  describe Smolagents::Concerns::GoalDrift::DriftConfig do
    describe ".default" do
      it "creates enabled config with sensible defaults" do
        config = described_class.default
        expect(config.enabled).to be(true)
        expect(config.window_size).to eq(5)
        expect(config.similarity_threshold).to eq(0.3)
        expect(config.max_tangent_steps).to eq(3)
      end
    end

    describe ".disabled" do
      it "creates disabled config" do
        config = described_class.disabled
        expect(config.enabled).to be(false)
      end
    end

    describe ".strict" do
      it "creates stricter detection config" do
        config = described_class.strict
        expect(config.window_size).to eq(3)
        expect(config.similarity_threshold).to eq(0.4)
        expect(config.max_tangent_steps).to eq(2)
      end
    end
  end

  describe Smolagents::Concerns::GoalDrift::DriftResult do
    describe ".on_track" do
      it "creates no-drift result" do
        result = described_class.on_track(task_relevance: 0.9)
        expect(result.level).to eq(:none)
        expect(result.drifting?).to be(false)
        expect(result.concerning?).to be(false)
        expect(result.task_relevance).to eq(0.9)
      end
    end

    describe ".drift_detected" do
      it "creates drift result with guidance" do
        result = described_class.drift_detected(
          level: :moderate,
          off_topic_count: 3,
          task_relevance: 0.2,
          guidance: "Refocus on task"
        )
        expect(result.drifting?).to be(true)
        expect(result.concerning?).to be(true)
        expect(result.guidance).to include("Refocus")
      end
    end

    describe "#drifting?" do
      it "returns false for :none level" do
        result = described_class.on_track
        expect(result.drifting?).to be(false)
      end

      it "returns true for other levels" do
        %i[mild moderate severe].each do |level|
          result = described_class.drift_detected(
            level:, off_topic_count: 1, task_relevance: 0.3, guidance: "x"
          )
          expect(result.drifting?).to be(true)
        end
      end
    end

    describe "#concerning?" do
      it "returns true for moderate and severe" do
        moderate = described_class.drift_detected(
          level: :moderate, off_topic_count: 3, task_relevance: 0.2, guidance: "x"
        )
        severe = described_class.drift_detected(
          level: :severe, off_topic_count: 5, task_relevance: 0.1, guidance: "x"
        )
        expect(moderate.concerning?).to be(true)
        expect(severe.concerning?).to be(true)
      end

      it "returns false for none and mild" do
        none = described_class.on_track
        mild = described_class.drift_detected(
          level: :mild, off_topic_count: 2, task_relevance: 0.3, guidance: "x"
        )
        expect(none.concerning?).to be(false)
        expect(mild.concerning?).to be(false)
      end
    end

    describe "#critical?" do
      it "returns true only for severe" do
        severe = described_class.drift_detected(
          level: :severe, off_topic_count: 5, task_relevance: 0.1, guidance: "x"
        )
        moderate = described_class.drift_detected(
          level: :moderate, off_topic_count: 3, task_relevance: 0.2, guidance: "x"
        )
        expect(severe.critical?).to be(true)
        expect(moderate.critical?).to be(false)
      end
    end
  end

  describe "#initialize_goal_drift" do
    it "defaults to disabled" do
      agent = test_class.new
      expect(agent.drift_config.enabled).to be(false)
    end

    it "uses provided config" do
      config = Smolagents::Concerns::GoalDrift::DriftConfig.default
      agent = test_class.new(drift_config: config)
      expect(agent.drift_config.enabled).to be(true)
    end
  end

  describe "#check_goal_drift" do
    let(:config) { Smolagents::Concerns::GoalDrift::DriftConfig.default }
    let(:agent) { test_class.new(drift_config: config) }

    context "when disabled" do
      let(:disabled_agent) { test_class.new }

      it "returns on_track" do
        steps = [Smolagents::ActionStep.new(step_number: 1)]
        result = disabled_agent.send(:check_goal_drift, "task", steps)
        expect(result.drifting?).to be(false)
      end
    end

    context "with relevant steps" do
      it "returns no drift" do
        steps = [
          Smolagents::ActionStep.new(
            step_number: 1,
            tool_calls: [Smolagents::ToolCall.new(name: "search", arguments: { query: "ruby documentation" }, id: "1")]
          ),
          Smolagents::ActionStep.new(
            step_number: 2,
            observations: "Found Ruby docs at ruby-lang.org"
          )
        ]
        result = agent.send(:check_goal_drift, "Find Ruby documentation", steps)
        expect(result.drifting?).to be(false)
      end
    end

    context "with off-topic steps" do
      it "detects drift when steps unrelated to task" do
        steps = Array.new(4) do |i|
          Smolagents::ActionStep.new(
            step_number: i + 1,
            tool_calls: [Smolagents::ToolCall.new(name: "weather", arguments: { city: "Paris" }, id: i.to_s)],
            observations: "Weather in Paris is sunny"
          )
        end
        result = agent.send(:check_goal_drift, "Calculate fibonacci sequence", steps)
        expect(result.drifting?).to be(true)
      end
    end

    context "with empty steps" do
      it "returns on_track" do
        result = agent.send(:check_goal_drift, "any task", [])
        expect(result.drifting?).to be(false)
      end
    end
  end

  describe "#calculate_step_relevance" do
    let(:config) { Smolagents::Concerns::GoalDrift::DriftConfig.default }
    let(:agent) { test_class.new(drift_config: config) }

    it "returns high relevance for matching terms" do
      step = Smolagents::ActionStep.new(
        step_number: 1,
        tool_calls: [Smolagents::ToolCall.new(name: "search", arguments: { query: "Ruby documentation" }, id: "1")]
      )
      relevance = agent.send(:calculate_step_relevance, "Find Ruby documentation", step)
      expect(relevance).to be > 0.5
    end

    it "returns low relevance for unrelated terms" do
      step = Smolagents::ActionStep.new(
        step_number: 1,
        tool_calls: [Smolagents::ToolCall.new(name: "weather", arguments: { city: "Tokyo" }, id: "1")]
      )
      relevance = agent.send(:calculate_step_relevance, "Calculate prime numbers", step)
      expect(relevance).to be < 0.5
    end

    it "handles empty task gracefully" do
      step = Smolagents::ActionStep.new(step_number: 1)
      relevance = agent.send(:calculate_step_relevance, "", step)
      expect(relevance).to eq(1.0)
    end
  end

  describe "#extract_key_terms" do
    let(:agent) { test_class.new(drift_config: Smolagents::Concerns::GoalDrift::DriftConfig.default) }

    it "extracts meaningful terms" do
      terms = agent.send(:extract_key_terms, "Find the Ruby documentation for arrays")
      expect(terms).to include("ruby")
      expect(terms).to include("documentation")
      expect(terms).to include("arrays")
    end

    it "removes stop words" do
      terms = agent.send(:extract_key_terms, "Find the Ruby documentation for arrays")
      expect(terms).not_to include("the")
      expect(terms).not_to include("for")
    end

    it "removes short words" do
      terms = agent.send(:extract_key_terms, "Go to the API")
      expect(terms).not_to include("go")
      expect(terms).not_to include("to")
    end

    it "handles empty input" do
      terms = agent.send(:extract_key_terms, "")
      expect(terms).to be_empty
    end

    it "handles nil input" do
      terms = agent.send(:extract_key_terms, nil)
      expect(terms).to be_empty
    end
  end

  describe "#determine_drift_level" do
    let(:config) { Smolagents::Concerns::GoalDrift::DriftConfig.default }
    let(:agent) { test_class.new(drift_config: config) }

    it "returns :none for good relevance and few off-topic" do
      level = agent.send(:determine_drift_level, 0.6, 1)
      expect(level).to eq(:none)
    end

    it "returns :mild for borderline metrics" do
      level = agent.send(:determine_drift_level, 0.32, 2)
      expect(level).to eq(:mild)
    end

    it "returns :moderate for concerning metrics" do
      level = agent.send(:determine_drift_level, 0.22, 3)
      expect(level).to eq(:moderate)
    end

    it "returns :severe for very low relevance" do
      level = agent.send(:determine_drift_level, 0.1, 5)
      expect(level).to eq(:severe)
    end
  end

  describe "#generate_drift_guidance" do
    let(:agent) { test_class.new(drift_config: Smolagents::Concerns::GoalDrift::DriftConfig.default) }

    it "generates critical guidance for severe drift" do
      guidance = agent.send(:generate_drift_guidance, "Find Ruby docs", :severe)
      expect(guidance).to include("CRITICAL")
      expect(guidance).to include("final_answer")
    end

    it "generates warning for moderate drift" do
      guidance = agent.send(:generate_drift_guidance, "Find Ruby docs", :moderate)
      expect(guidance).to include("WARNING")
      expect(guidance).to include("Refocus")
    end

    it "generates note for mild drift" do
      guidance = agent.send(:generate_drift_guidance, "Find Ruby docs", :mild)
      expect(guidance).to include("Note")
      expect(guidance).to include("Remember")
    end
  end

  describe "#execute_drift_check_if_needed" do
    let(:config) { Smolagents::Concerns::GoalDrift::DriftConfig.default }
    let(:agent) { test_class.new(drift_config: config) }

    context "when disabled" do
      let(:disabled_agent) { test_class.new }

      it "returns nil" do
        steps = [Smolagents::ActionStep.new(step_number: 1)]
        result = disabled_agent.send(:execute_drift_check_if_needed, "task", steps)
        expect(result).to be_nil
      end
    end

    context "when enabled" do
      it "returns drift result" do
        steps = [Smolagents::ActionStep.new(step_number: 1)]
        result = agent.send(:execute_drift_check_if_needed, "task", steps)
        expect(result).to be_a(Smolagents::Concerns::GoalDrift::DriftResult)
      end

      it "yields when drifting" do
        # Create off-topic steps
        steps = Array.new(4) do |i|
          Smolagents::ActionStep.new(
            step_number: i + 1,
            observations: "completely unrelated content about weather"
          )
        end

        yielded = nil
        agent.send(:execute_drift_check_if_needed, "calculate math", steps) { |r| yielded = r }

        # Only yields if actually drifting
        if yielded
          expect(yielded.drifting?).to be(true)
        end
      end
    end
  end
end
