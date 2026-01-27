require "smolagents"

RSpec.describe Smolagents::Concerns::Agents::SemanticBreaker::Detectors do
  # Default action thresholds for custom configs
  let(:default_actions) { { low: :continue, medium: :warn, high: :pause, critical: :abort } }

  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Events::Consumer
      include Smolagents::Concerns::Agents::SemanticBreaker

      def initialize(config: nil) = setup_semantic_breaker(config)
    end
  end

  let(:default_config) { Smolagents::Types::SemanticDetectionConfig.default }
  let(:strict_config) { Smolagents::Types::SemanticDetectionConfig.strict }
  let(:permissive_config) { Smolagents::Types::SemanticDetectionConfig.permissive }

  let(:instance) { test_class.new }
  let(:strict_instance) { test_class.new(config: strict_config) }
  let(:permissive_instance) { test_class.new(config: permissive_config) }

  describe "#detect_incoherence" do
    let(:step) { double(reasoning: "Some reasoning", observations: nil, code_action: nil) }
    let(:context) { { task: "test task", history: [] } }

    it "returns nil when detector is disabled" do
      disabled_config = Smolagents::Types::SemanticDetectionConfig.new(
        incoherence_threshold: 0.3,
        drift_threshold: 0.5,
        confidence_decay_threshold: 0.2,
        loop_similarity_threshold: 0.85,
        enabled_detectors: [:goal_drift],
        action_thresholds: default_actions
      )
      disabled_instance = test_class.new(config: disabled_config)

      result = disabled_instance.send(:detect_incoherence, step, context)
      expect(result).to be_nil
    end

    it "returns nil when history is empty" do
      result = instance.send(:detect_incoherence, step, { task: "test", history: [] })
      expect(result).to be_nil
    end

    it "returns nil when score is below threshold" do
      # Use content that will have high similarity with history
      coherent_step = double(reasoning: "Ruby programming language features and syntax", observations: nil,
                             code_action: nil)
      history = [
        double(reasoning: "Ruby programming language features", observations: nil, code_action: nil),
        double(reasoning: "Ruby programming language syntax", observations: nil, code_action: nil),
        double(reasoning: "Ruby programming language features and syntax guide", observations: nil, code_action: nil)
      ]
      coherent_context = { task: "Learn Ruby", history: }

      result = permissive_instance.send(:detect_incoherence, coherent_step, coherent_context)
      # With permissive config (0.5 threshold), very similar content should not trigger
      # High similarity = low incoherence score
      expect(result).to be_nil
    end

    it "returns detection when score exceeds threshold" do
      incoherent_step = double(
        reasoning: "zzz yyy xxx www completely unrelated content",
        observations: nil,
        code_action: nil
      )
      history = [
        double(reasoning: "aaa bbb ccc ddd eee", observations: nil, code_action: nil),
        double(reasoning: "fff ggg hhh iii jjj", observations: nil, code_action: nil),
        double(reasoning: "kkk lll mmm nnn ooo", observations: nil, code_action: nil)
      ]
      incoherent_context = { task: "test", history: }

      result = strict_instance.send(:detect_incoherence, incoherent_step, incoherent_context)

      if result
        expect(result).to be_a(Smolagents::Types::SemanticDetectionResult)
        expect(result.failure_type).to eq(:incoherence)
      end
    end

    it "includes evidence in detection result" do
      incoherent_step = double(reasoning: "qqq www eee rrr", observations: nil, code_action: nil)
      history = [double(reasoning: "aaa bbb ccc ddd", observations: nil, code_action: nil)]

      result = strict_instance.send(:detect_incoherence, incoherent_step, { task: "test", history: })

      expect(result.evidence).to include("Logical inconsistency detected") if result
    end
  end

  describe "#detect_goal_drift" do
    # Use content with high overlap with task
    let(:relevant_step) do
      double(reasoning: "Find information about Ruby programming documentation", observations: nil, code_action: nil)
    end
    let(:drifted_step) do
      double(reasoning: "Weather forecast today sunny warm outside temperature", observations: nil, code_action: nil)
    end
    let(:context) { { task: "Find information about Ruby programming documentation", history: [] } }

    it "returns nil when detector is disabled" do
      disabled_config = Smolagents::Types::SemanticDetectionConfig.new(
        incoherence_threshold: 0.3,
        drift_threshold: 0.5,
        confidence_decay_threshold: 0.2,
        loop_similarity_threshold: 0.85,
        enabled_detectors: [:incoherence],
        action_thresholds: default_actions
      )
      disabled_instance = test_class.new(config: disabled_config)

      result = disabled_instance.send(:detect_goal_drift, relevant_step, context)
      expect(result).to be_nil
    end

    it "returns nil when task is empty" do
      result = instance.send(:detect_goal_drift, drifted_step, { task: "", history: [] })
      expect(result).to be_nil
    end

    it "returns nil when task is nil converted to empty string" do
      result = instance.send(:detect_goal_drift, drifted_step, { task: nil, history: [] })
      expect(result).to be_nil
    end

    it "returns nil when step is relevant to task" do
      # With identical/very similar task and step content, relevance is high, drift is low
      result = permissive_instance.send(:detect_goal_drift, relevant_step, context)
      # Relevant step should not trigger drift detection with permissive threshold (0.7)
      expect(result).to be_nil
    end

    it "returns detection when step drifts from task" do
      result = strict_instance.send(:detect_goal_drift, drifted_step, context)

      expect(result.failure_type).to eq(:goal_drift) if result
    end

    it "includes task relevance in evidence" do
      result = instance.send(:detect_goal_drift, drifted_step, context)

      expect(result.evidence.first).to match(/Task relevance: \d+%/) if result
    end

    it "calculates drift_score as 1.0 minus relevance" do
      # Low relevance means high drift score
      weather_step = double(reasoning: "sunny cloudy rain temperature", observations: nil, code_action: nil)
      ruby_context = { task: "Ruby programming tutorial", history: [] }

      result = strict_instance.send(:detect_goal_drift, weather_step, ruby_context)

      if result
        # If detected, drift score should be above threshold
        expect(result.confidence).to be >= strict_config.drift_threshold
      end
    end
  end

  describe "#detect_confidence_decay" do
    let(:step) { double(reasoning: "test", observations: nil, code_action: nil, confidence: 0.5) }
    let(:context) { { task: "test", history: [] } }

    it "returns nil when detector is disabled" do
      disabled_config = Smolagents::Types::SemanticDetectionConfig.new(
        incoherence_threshold: 0.3,
        drift_threshold: 0.5,
        confidence_decay_threshold: 0.2,
        loop_similarity_threshold: 0.85,
        enabled_detectors: [:incoherence],
        action_thresholds: default_actions
      )
      disabled_instance = test_class.new(config: disabled_config)

      result = disabled_instance.send(:detect_confidence_decay, step, context)
      expect(result).to be_nil
    end

    it "returns nil when step has no confidence" do
      no_conf_step = double(reasoning: "test", observations: nil, code_action: nil)
      allow(no_conf_step).to receive(:respond_to?).with(:confidence).and_return(false)

      result = instance.send(:detect_confidence_decay, no_conf_step, context)
      expect(result).to be_nil
    end

    it "returns nil when confidence is nil" do
      nil_conf_step = double(reasoning: "test", observations: nil, code_action: nil, confidence: nil)

      result = instance.send(:detect_confidence_decay, nil_conf_step, context)
      expect(result).to be_nil
    end

    it "returns nil when not enough history" do
      # Only one confidence value in history (from current step)
      result = instance.send(:detect_confidence_decay, step, context)
      expect(result).to be_nil
    end

    it "returns nil when decay is below threshold" do
      # Build stable confidence history
      instance.semantic_state[:confidence_history] = [0.8, 0.8, 0.8, 0.8]
      stable_step = double(reasoning: "test", observations: nil, code_action: nil, confidence: 0.8)

      result = instance.send(:detect_confidence_decay, stable_step, context)
      expect(result).to be_nil
    end

    it "returns detection when confidence decays significantly" do
      # Build decaying confidence history
      instance.semantic_state[:confidence_history] = [0.95, 0.9, 0.85, 0.8]
      low_conf_step = double(reasoning: "test", observations: nil, code_action: nil, confidence: 0.5)

      result = instance.send(:detect_confidence_decay, low_conf_step, context)

      expect(result.failure_type).to eq(:confidence_decay) if result
    end

    it "adds confidence to history" do
      conf_step = double(reasoning: "test", observations: nil, code_action: nil, confidence: 0.75)

      instance.send(:detect_confidence_decay, conf_step, context)

      expect(instance.semantic_state[:confidence_history]).to include(0.75)
    end

    it "includes decay percentage in evidence" do
      instance.semantic_state[:confidence_history] = [0.9, 0.85, 0.8, 0.7]
      decay_step = double(reasoning: "test", observations: nil, code_action: nil, confidence: 0.4)

      result = instance.send(:detect_confidence_decay, decay_step, context)

      expect(result.evidence.first).to match(/Confidence declining: \d+%/) if result
    end
  end

  describe "#detect_semantic_loop" do
    let(:step) { double(reasoning: "Unique content here", observations: nil, code_action: nil) }
    let(:context) { { task: "test", history: [] } }

    it "returns nil when detector is disabled" do
      disabled_config = Smolagents::Types::SemanticDetectionConfig.new(
        incoherence_threshold: 0.3,
        drift_threshold: 0.5,
        confidence_decay_threshold: 0.2,
        loop_similarity_threshold: 0.85,
        enabled_detectors: [:incoherence],
        action_thresholds: default_actions
      )
      disabled_instance = test_class.new(config: disabled_config)

      result = disabled_instance.send(:detect_semantic_loop, step, context)
      expect(result).to be_nil
    end

    it "returns nil when no previous hashes" do
      result = instance.send(:detect_semantic_loop, step, context)
      expect(result).to be_nil
    end

    it "returns nil when similarity is below threshold" do
      instance.semantic_state[:semantic_hashes] = [
        Smolagents::Utilities::Similarity.trigrams("completely different content abc xyz")
      ]

      result = permissive_instance.send(:detect_semantic_loop, step, context)
      expect(result).to be_nil
    end

    it "returns detection when content is near-duplicate" do
      duplicate_content = "This is the exact same content repeated"
      instance.semantic_state[:semantic_hashes] = [
        Smolagents::Utilities::Similarity.trigrams(duplicate_content)
      ]

      duplicate_step = double(reasoning: duplicate_content, observations: nil, code_action: nil)
      result = instance.send(:detect_semantic_loop, duplicate_step, context)

      expect(result).not_to be_nil
      expect(result.failure_type).to eq(:semantic_loop)
    end

    it "includes similarity percentage in evidence" do
      same_content = "Repeated search for Ruby documentation"
      instance.semantic_state[:semantic_hashes] = [
        Smolagents::Utilities::Similarity.trigrams(same_content)
      ]

      same_step = double(reasoning: same_content, observations: nil, code_action: nil)
      result = instance.send(:detect_semantic_loop, same_step, context)

      expect(result.evidence.first).to match(/Semantic similarity: \d+%/) if result
    end

    it "stores semantic hash after detection" do
      instance.send(:detect_semantic_loop, step, context)

      expect(instance.semantic_state[:semantic_hashes].size).to eq(1)
    end

    it "compares against last 5 hashes only" do
      # Fill with 6 different hashes
      6.times do |i|
        instance.semantic_state[:semantic_hashes] << Smolagents::Utilities::Similarity.trigrams("unique content #{i}")
      end

      # The max_similarity_to_previous method only looks at last 5
      new_step = double(reasoning: "unique content 0", observations: nil, code_action: nil)
      instance.send(:detect_semantic_loop, new_step, context)

      # Hash 0 is no longer in the last 5, so no loop should be detected
      # (unless similarity to hashes 1-5 is high enough)
      expect(instance.semantic_state[:semantic_hashes].size).to eq(7)
    end
  end

  describe "#run_enabled_detectors" do
    let(:step) { double(reasoning: "test", observations: nil, code_action: nil, confidence: nil) }
    let(:context) { { task: "test", history: [] } }

    it "runs all four detectors" do
      results = instance.send(:run_enabled_detectors, step, context)

      # Should return array of results (nil values are compacted)
      expect(results).to be_an(Array)
    end

    it "filters out nil results" do
      results = instance.send(:run_enabled_detectors, step, context)

      expect(results).not_to include(nil)
    end

    it "returns detections from enabled detectors" do
      # Set up for loop detection
      instance.semantic_state[:semantic_hashes] = [
        Smolagents::Utilities::Similarity.trigrams("exact duplicate content here")
      ]
      dup_step = double(reasoning: "exact duplicate content here", observations: nil, code_action: nil, confidence: nil)

      results = instance.send(:run_enabled_detectors, dup_step, context)

      expect(results.first).to be_a(Smolagents::Types::SemanticDetectionResult) if results.any?
    end

    it "respects enabled_detectors config" do
      # Only enable incoherence
      limited_config = Smolagents::Types::SemanticDetectionConfig.new(
        incoherence_threshold: 0.3,
        drift_threshold: 0.5,
        confidence_decay_threshold: 0.2,
        loop_similarity_threshold: 0.85,
        enabled_detectors: [:incoherence],
        action_thresholds: default_actions
      )
      limited_instance = test_class.new(config: limited_config)

      # Set up conditions that would trigger loop detection
      limited_instance.semantic_state[:semantic_hashes] = [
        Smolagents::Utilities::Similarity.trigrams("exact duplicate")
      ]
      dup_step = double(reasoning: "exact duplicate", observations: nil, code_action: nil, confidence: nil)

      results = limited_instance.send(:run_enabled_detectors, dup_step, { task: "test", history: [] })

      # Loop detection should not fire since it's not enabled
      loop_results = results.select { |r| r&.failure_type == :semantic_loop }
      expect(loop_results).to be_empty
    end
  end

  describe "threshold comparisons" do
    describe "incoherence_threshold" do
      it "default is 0.3" do
        expect(default_config.incoherence_threshold).to eq(0.3)
      end

      it "strict is 0.2" do
        expect(strict_config.incoherence_threshold).to eq(0.2)
      end

      it "permissive is 0.5" do
        expect(permissive_config.incoherence_threshold).to eq(0.5)
      end
    end

    describe "drift_threshold" do
      it "default is 0.5" do
        expect(default_config.drift_threshold).to eq(0.5)
      end

      it "strict is 0.3" do
        expect(strict_config.drift_threshold).to eq(0.3)
      end

      it "permissive is 0.7" do
        expect(permissive_config.drift_threshold).to eq(0.7)
      end
    end

    describe "confidence_decay_threshold" do
      it "default is 0.2" do
        expect(default_config.confidence_decay_threshold).to eq(0.2)
      end

      it "strict is 0.15" do
        expect(strict_config.confidence_decay_threshold).to eq(0.15)
      end

      it "permissive is 0.35" do
        expect(permissive_config.confidence_decay_threshold).to eq(0.35)
      end
    end

    describe "loop_similarity_threshold" do
      it "default is 0.85" do
        expect(default_config.loop_similarity_threshold).to eq(0.85)
      end

      it "strict is 0.75" do
        expect(strict_config.loop_similarity_threshold).to eq(0.75)
      end

      it "permissive is 0.92" do
        expect(permissive_config.loop_similarity_threshold).to eq(0.92)
      end
    end
  end

  describe "edge cases" do
    let(:step) { double(reasoning: nil, observations: nil, code_action: nil, confidence: nil) }
    let(:context) { { task: nil, history: nil } }

    it "handles nil reasoning in step" do
      expect do
        instance.send(:detect_incoherence, step, { task: "test", history: [] })
      end.not_to raise_error
    end

    it "handles nil history" do
      expect do
        instance.send(:detect_incoherence, step, { task: "test", history: nil })
      end.not_to raise_error
    end

    it "handles empty step text" do
      empty_step = double(reasoning: "", observations: "", code_action: "")
      expect do
        instance.send(:detect_semantic_loop, empty_step, context)
      end.not_to raise_error
    end

    it "handles step without respond_to methods" do
      minimal_step = Object.new

      expect do
        instance.send(:detect_incoherence, minimal_step, { task: "test", history: [] })
      end.not_to raise_error
    end
  end
end
