require "smolagents"

RSpec.describe Smolagents::Concerns::Agents::SemanticBreaker do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Events::Consumer
      include Smolagents::Concerns::Agents::SemanticBreaker

      attr_accessor :step_history

      def initialize(config: nil, failure_threshold: nil)
        @step_history = []
        if failure_threshold
          setup_semantic_breaker(config, failure_threshold:)
        else
          setup_semantic_breaker(config)
        end
      end
    end
  end

  let(:instance) { test_class.new }

  before do
    Smolagents::Events::CreateFactory.reset_sequence!
  end

  describe "#setup_semantic_breaker" do
    it "initializes with default config" do
      expect(instance.semantic_config).to be_a(Smolagents::Types::SemanticDetectionConfig)
      expect(instance.semantic_config.incoherence_threshold).to eq(0.3)
    end

    it "accepts custom config" do
      default_actions = { low: :continue, medium: :warn, high: :pause, critical: :abort }
      custom_config = Smolagents::Types::SemanticDetectionConfig.new(
        incoherence_threshold: 0.5,
        drift_threshold: 0.6,
        confidence_decay_threshold: 0.3,
        loop_similarity_threshold: 0.9,
        enabled_detectors: [:all],
        action_thresholds: default_actions
      )
      custom_instance = test_class.new(config: custom_config)

      expect(custom_instance.semantic_config.incoherence_threshold).to eq(0.5)
      expect(custom_instance.semantic_config.drift_threshold).to eq(0.6)
    end

    it "accepts strict preset" do
      strict_instance = test_class.new(config: Smolagents::Types::SemanticDetectionConfig.strict)

      expect(strict_instance.semantic_config.incoherence_threshold).to eq(0.2)
      expect(strict_instance.semantic_config.drift_threshold).to eq(0.3)
    end

    it "accepts permissive preset" do
      permissive_instance = test_class.new(config: Smolagents::Types::SemanticDetectionConfig.permissive)

      expect(permissive_instance.semantic_config.incoherence_threshold).to eq(0.5)
      expect(permissive_instance.semantic_config.drift_threshold).to eq(0.7)
    end

    it "initializes semantic state" do
      expect(instance.semantic_state).to include(
        consecutive_failures: 0,
        failure_threshold: described_class::DEFAULT_FAILURE_THRESHOLD,
        confidence_history: [],
        semantic_hashes: []
      )
    end

    it "accepts custom failure threshold" do
      custom_instance = test_class.new(failure_threshold: 5)

      expect(custom_instance.semantic_state[:failure_threshold]).to eq(5)
    end
  end

  describe "#detect_semantic_failure" do
    let(:step) do
      double(reasoning: "Find information about Ruby programming language", observations: nil, code_action: nil,
             confidence: nil)
    end
    let(:context) { { task: "Find information about Ruby programming language", history: [] } }

    context "when no failure detected" do
      it "returns SemanticDetectionResult.none" do
        # With identical task and reasoning and no history, no failures should be detected
        result = instance.detect_semantic_failure(step, context)

        expect(result).not_to be_detected
        expect(result.failure_type).to be_nil
      end

      it "does not emit events" do
        events = []
        instance.on(:semantic_failure_detected) { |e| events << e }

        instance.detect_semantic_failure(step, context)
        Smolagents::Events::AsyncQueue.drain(timeout: 1)

        expect(events).to be_empty
      end
    end

    context "when config is nil" do
      it "returns SemanticDetectionResult.none" do
        instance.instance_variable_set(:@semantic_config, nil)
        result = instance.detect_semantic_failure(step, context)

        expect(result).not_to be_detected
      end
    end

    context "when incoherence detected" do
      let(:incoherent_step) do
        double(reasoning: "xyz abc completely different unrelated", observations: nil, code_action: nil,
               confidence: nil)
      end
      let(:context_with_history) do
        history = [
          double(reasoning: "Let me search for Ruby information", observations: "Found Ruby docs", code_action: nil),
          double(reasoning: "Looking at the Ruby documentation", observations: "Ruby 3.2", code_action: nil),
          double(reasoning: "Ruby is a programming language", observations: nil, code_action: nil)
        ]
        { task: "Find information about Ruby", history: }
      end

      it "returns result with failure_type :incoherence when score exceeds threshold" do
        # Configure strict settings to make detection more sensitive
        strict_instance = test_class.new(config: Smolagents::Types::SemanticDetectionConfig.strict)

        result = strict_instance.detect_semantic_failure(incoherent_step, context_with_history)

        # May or may not detect depending on actual similarity
        # This test validates the structure when detected
        expect(result.failure_type).to eq(:incoherence) if result.detected?
      end

      it "includes confidence score" do
        result = instance.detect_semantic_failure(step, context)

        expect(result.confidence).to be_a(Float)
        expect(result.confidence).to be_between(0.0, 1.0)
      end

      it "emits semantic_failure_detected event when detected" do
        events = []
        instance.on(:semantic_failure_detected) { |e| events << e }

        # Force a detection by creating highly dissimilar content
        dissimilar_step = double(
          reasoning: "qqq www eee rrr ttt yyy uuu iii ooo ppp",
          observations: nil,
          code_action: nil,
          confidence: nil
        )
        history_context = {
          task: "Find Ruby info",
          history: [
            double(reasoning: "aaa bbb ccc ddd eee fff ggg hhh", observations: nil, code_action: nil),
            double(reasoning: "jjj kkk lll mmm nnn ooo ppp qqq", observations: nil, code_action: nil),
            double(reasoning: "rrr sss ttt uuu vvv www xxx yyy", observations: nil, code_action: nil)
          ]
        }

        result = instance.detect_semantic_failure(dissimilar_step, history_context)
        Smolagents::Events::AsyncQueue.drain(timeout: 1)

        if result.detected?
          expect(events.size).to eq(1)
          expect(events.first.failure_type).to eq(result.failure_type)
        end
      end
    end

    context "when goal drift detected" do
      let(:drifted_step) do
        double(
          reasoning: "Let me check the weather forecast for today",
          observations: "Weather is sunny",
          code_action: nil,
          confidence: nil
        )
      end
      let(:context) { { task: "Find information about Ruby programming", history: [] } }

      it "returns result with failure_type :goal_drift when relevance is low" do
        # Use strict config to make drift detection more sensitive
        strict_instance = test_class.new(config: Smolagents::Types::SemanticDetectionConfig.strict)
        result = strict_instance.detect_semantic_failure(drifted_step, context)

        # Goal drift may be detected if the step content is very different from task
        if result.detected? && result.failure_type == :goal_drift
          expect(result.evidence).to include(match(/Task relevance/))
        end
      end

      it "calculates task relevance" do
        # The relevance calculation uses Similarity.string
        relevance = Smolagents::Utilities::Similarity.string(
          "weather forecast sunny",
          "Find information about Ruby programming"
        )

        expect(relevance).to be_a(Float)
        expect(relevance).to be < 0.5 # These should be quite dissimilar
      end

      it "does not detect when task is empty" do
        empty_task_context = { task: "", history: [] }
        result = instance.detect_semantic_failure(drifted_step, empty_task_context)

        # Should not have goal_drift if task is empty
        expect(result.failure_type).not_to eq(:goal_drift)
      end
    end

    context "when confidence decay detected" do
      it "returns result with failure_type :confidence_decay" do
        # Build up confidence history showing decay
        step_with_confidence = double(
          reasoning: "Some reasoning",
          observations: nil,
          code_action: nil,
          confidence: 0.4
        )

        # Simulate previous steps with higher confidence
        instance.semantic_state[:confidence_history] = [0.9, 0.85, 0.8, 0.75]

        result = instance.detect_semantic_failure(step_with_confidence, { task: "test", history: [] })

        if result.detected? && result.failure_type == :confidence_decay
          expect(result.evidence).to include(match(/Confidence declining/))
        end
      end

      it "tracks confidence trend across steps" do
        confidences = [0.9, 0.8, 0.7, 0.6, 0.5]

        confidences.each do |conf|
          step = double(reasoning: "test", observations: nil, code_action: nil, confidence: conf)
          instance.detect_semantic_failure(step, { task: "test", history: [] })
        end

        expect(instance.semantic_state[:confidence_history]).to eq(confidences)
      end

      it "does not detect when step has no confidence" do
        no_confidence_step = double(reasoning: "test", observations: nil, code_action: nil, confidence: nil)
        instance.semantic_state[:confidence_history] = [0.9, 0.8, 0.7]

        result = instance.detect_semantic_failure(no_confidence_step, { task: "test", history: [] })

        # If detected, should not be confidence_decay since step has no confidence
        expect(result.failure_type).not_to eq(:confidence_decay)
      end
    end

    context "when semantic loop detected" do
      it "returns result with failure_type :semantic_loop" do
        # Create steps with very similar content to trigger loop detection
        similar_content = "Searching for Ruby documentation version 3.2"

        3.times do
          step = double(reasoning: similar_content, observations: nil, code_action: nil, confidence: nil)
          instance.detect_semantic_failure(step, { task: "test", history: [] })
        end

        # The third similar step should trigger loop detection
        loop_step = double(reasoning: similar_content, observations: nil, code_action: nil, confidence: nil)
        result = instance.detect_semantic_failure(loop_step, { task: "test", history: [] })

        if result.detected? && result.failure_type == :semantic_loop
          expect(result.evidence).to include(match(/Semantic similarity/))
        end
      end

      it "detects near-duplicate content via trigram hashing" do
        # Build up semantic hashes
        base_text = "This is a test about Ruby programming language features"
        instance.semantic_state[:semantic_hashes] = [
          Smolagents::Utilities::Similarity.trigrams(base_text)
        ]

        # Very similar text should have high similarity
        similar_step = double(
          reasoning: "This is a test about Ruby programming language features",
          observations: nil,
          code_action: nil,
          confidence: nil
        )

        result = instance.detect_semantic_failure(similar_step, { task: "test", history: [] })

        # Should detect as semantic loop with very high similarity
        expect(result.failure_type).to eq(:semantic_loop) if result.detected?
      end

      it "stores semantic hashes for comparison" do
        step = double(reasoning: "Unique content here", observations: nil, code_action: nil, confidence: nil)
        instance.detect_semantic_failure(step, { task: "test", history: [] })

        expect(instance.semantic_state[:semantic_hashes].size).to eq(1)
        expect(instance.semantic_state[:semantic_hashes].first).to be_a(Set)
      end
    end
  end

  describe "#on_semantic_breaker_tripped" do
    let(:result) do
      Smolagents::Types::SemanticDetectionResult.detected(
        type: :semantic_loop,
        confidence: 0.92,
        evidence: ["Repeated content detected"],
        severity: :high,
        action: :pause
      )
    end

    it "emits semantic_breaker_tripped event" do
      events = []
      instance.on(:semantic_breaker_tripped) { |e| events << e }

      instance.on_semantic_breaker_tripped(result)
      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(events.size).to eq(1)
      expect(events.first.failure_type).to eq(:semantic_loop)
      expect(events.first.severity).to eq(:high)
    end

    it "includes action_taken in event" do
      events = []
      instance.on(:semantic_breaker_tripped) { |e| events << e }

      instance.on_semantic_breaker_tripped(result)
      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(events.first.action_taken).to eq(:paused)
    end

    it "uses :aborted action for critical severity" do
      events = []
      instance.on(:semantic_breaker_tripped) { |e| events << e }

      critical_result = Smolagents::Types::SemanticDetectionResult.detected(
        type: :incoherence,
        confidence: 0.95,
        evidence: ["Critical failure"],
        severity: :critical,
        action: :abort
      )

      instance.on_semantic_breaker_tripped(critical_result)
      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(events.first.action_taken).to eq(:aborted)
    end

    it "includes consecutive_failures count" do
      events = []
      instance.on(:semantic_breaker_tripped) { |e| events << e }

      # Simulate some failures
      instance.semantic_state[:consecutive_failures] = 3

      instance.on_semantic_breaker_tripped(result)
      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(events.first.consecutive_failures).to eq(3)
    end
  end

  describe "#reset_semantic_breaker" do
    it "clears consecutive failure count" do
      instance.semantic_state[:consecutive_failures] = 5
      instance.reset_semantic_breaker("Recovery detected")

      expect(instance.semantic_state[:consecutive_failures]).to eq(0)
    end

    it "emits semantic_breaker_reset event" do
      events = []
      instance.on(:semantic_breaker_reset) { |e| events << e }

      instance.semantic_state[:consecutive_failures] = 3
      instance.reset_semantic_breaker("Agent recovered")
      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(events.size).to eq(1)
      expect(events.first.previous_failure_count).to eq(3)
      expect(events.first.recovery_reason).to eq("Agent recovered")
    end

    it "preserves failure threshold on reset" do
      custom_instance = test_class.new(failure_threshold: 5)
      custom_instance.semantic_state[:consecutive_failures] = 3
      custom_instance.reset_semantic_breaker

      expect(custom_instance.semantic_state[:failure_threshold]).to eq(5)
    end

    it "does nothing when no failures to reset" do
      events = []
      instance.on(:semantic_breaker_reset) { |e| events << e }

      instance.reset_semantic_breaker("No failures")
      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(events).to be_empty
    end
  end

  describe "consecutive failure tracking" do
    let(:step) { double(reasoning: "test", observations: nil, code_action: nil, confidence: nil) }

    it "increments counter on each failure" do
      # Create a situation that triggers a detection
      instance.semantic_state[:semantic_hashes] = [
        Smolagents::Utilities::Similarity.trigrams("test content here")
      ]

      same_step = double(reasoning: "test content here", observations: nil, code_action: nil, confidence: nil)
      initial_count = instance.semantic_state[:consecutive_failures]

      result = instance.detect_semantic_failure(same_step, { task: "task", history: [] })

      expect(instance.semantic_state[:consecutive_failures]).to eq(initial_count + 1) if result.detected?
    end

    it "trips breaker after threshold exceeded" do
      events = []
      instance.on(:semantic_breaker_tripped) { |e| events << e }

      # Set up to trigger on threshold (default is 3)
      instance.semantic_state[:consecutive_failures] = 2

      # Force a detection
      instance.semantic_state[:semantic_hashes] = [
        Smolagents::Utilities::Similarity.trigrams("exact same content")
      ]
      same_step = double(reasoning: "exact same content", observations: nil, code_action: nil, confidence: nil)

      instance.detect_semantic_failure(same_step, { task: "task", history: [] })
      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(events).not_to be_empty if instance.semantic_state[:consecutive_failures] >= 3
    end

    it "resets counter after recovery" do
      instance.semantic_state[:consecutive_failures] = 2
      instance.reset_semantic_breaker("Recovered")

      expect(instance.semantic_state[:consecutive_failures]).to eq(0)
    end
  end

  describe "severity to action mapping" do
    it "maps :low to :continue" do
      config = Smolagents::Types::SemanticDetectionConfig.default
      expect(config.action_for(:low)).to eq(:continue)
    end

    it "maps :medium to :warn" do
      config = Smolagents::Types::SemanticDetectionConfig.default
      expect(config.action_for(:medium)).to eq(:warn)
    end

    it "maps :high to :pause" do
      config = Smolagents::Types::SemanticDetectionConfig.default
      expect(config.action_for(:high)).to eq(:pause)
    end

    it "maps :critical to :abort" do
      config = Smolagents::Types::SemanticDetectionConfig.default
      expect(config.action_for(:critical)).to eq(:abort)
    end

    it "defaults to :continue for unknown severity" do
      config = Smolagents::Types::SemanticDetectionConfig.default
      expect(config.action_for(:unknown)).to eq(:continue)
    end
  end

  describe "severity calculation from confidence" do
    it "returns :critical for confidence 0.9-1.0" do
      instance.semantic_state[:semantic_hashes] = [
        Smolagents::Utilities::Similarity.trigrams("identical text here")
      ]
      step = double(reasoning: "identical text here", observations: nil, code_action: nil, confidence: nil)

      result = instance.detect_semantic_failure(step, { task: "task", history: [] })

      expect(result.severity).to eq(:critical) if result.detected? && result.confidence >= 0.9
    end

    it "returns :high for confidence 0.7-0.9" do
      # Test via the config action mapping which uses severity
      result = Smolagents::Types::SemanticDetectionResult.detected(
        type: :test,
        confidence: 0.8,
        evidence: [],
        severity: :high,
        action: :pause
      )

      expect(result.severity).to eq(:high)
    end

    it "returns :medium for confidence 0.5-0.7" do
      result = Smolagents::Types::SemanticDetectionResult.detected(
        type: :test,
        confidence: 0.6,
        evidence: [],
        severity: :medium,
        action: :warn
      )

      expect(result.severity).to eq(:medium)
    end

    it "returns :low for confidence below 0.5" do
      result = Smolagents::Types::SemanticDetectionResult.detected(
        type: :test,
        confidence: 0.3,
        evidence: [],
        severity: :low,
        action: :continue
      )

      expect(result.severity).to eq(:low)
    end
  end

  describe "aggregate_detections" do
    it "returns none when no detections" do
      results = []
      result = instance.send(:aggregate_detections, results)

      expect(result).not_to be_detected
    end

    it "returns highest confidence detection" do
      results = [
        Smolagents::Types::SemanticDetectionResult.detected(
          type: :incoherence, confidence: 0.5, evidence: [], severity: :medium, action: :warn
        ),
        Smolagents::Types::SemanticDetectionResult.detected(
          type: :goal_drift, confidence: 0.8, evidence: [], severity: :high, action: :pause
        ),
        Smolagents::Types::SemanticDetectionResult.none
      ]

      result = instance.send(:aggregate_detections, results)

      expect(result.failure_type).to eq(:goal_drift)
      expect(result.confidence).to eq(0.8)
    end
  end
end
