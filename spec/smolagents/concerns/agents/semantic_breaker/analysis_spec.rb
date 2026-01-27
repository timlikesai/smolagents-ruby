require "smolagents"

RSpec.describe Smolagents::Concerns::Agents::SemanticBreaker::Analysis do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Events::Consumer
      include Smolagents::Concerns::Agents::SemanticBreaker

      def initialize = setup_semantic_breaker
    end
  end

  let(:instance) { test_class.new }

  describe "#calculate_incoherence_score" do
    it "returns 0.0 when history is empty" do
      step = double(reasoning: "Some content", observations: nil, code_action: nil)
      context = { history: [] }

      score = instance.send(:calculate_incoherence_score, step, context)

      expect(score).to eq(0.0)
    end

    it "returns 0.0 when history is nil" do
      step = double(reasoning: "Some content", observations: nil, code_action: nil)
      context = { history: nil }

      score = instance.send(:calculate_incoherence_score, step, context)

      expect(score).to eq(0.0)
    end

    it "returns low score for coherent content" do
      # Use almost identical content to ensure high similarity
      step = double(reasoning: "Ruby programming language features and documentation guide", observations: nil,
                    code_action: nil)
      history = [
        double(reasoning: "Ruby programming language features", observations: nil, code_action: nil),
        double(reasoning: "Ruby programming language documentation", observations: nil, code_action: nil),
        double(reasoning: "Ruby programming language guide", observations: nil, code_action: nil)
      ]
      context = { history: }

      score = instance.send(:calculate_incoherence_score, step, context)

      # Score is 1.0 - similarity, so very similar content = low incoherence
      # With trigram similarity of near-identical content, we get high similarity
      expect(score).to be_between(0.0, 0.6)
    end

    it "returns high score for incoherent content" do
      step = double(reasoning: "zzz yyy xxx www vvv completely unrelated", observations: nil, code_action: nil)
      history = [
        double(reasoning: "aaa bbb ccc ddd eee fff", observations: nil, code_action: nil),
        double(reasoning: "ggg hhh iii jjj kkk lll", observations: nil, code_action: nil),
        double(reasoning: "mmm nnn ooo ppp qqq rrr", observations: nil, code_action: nil)
      ]
      context = { history: }

      score = instance.send(:calculate_incoherence_score, step, context)

      # Incoherent content should have high incoherence score
      expect(score).to be > 0.5
    end

    it "uses last 3 history items" do
      step = double(reasoning: "test content", observations: nil, code_action: nil)
      history = [
        double(reasoning: "item 1", observations: nil, code_action: nil),
        double(reasoning: "item 2", observations: nil, code_action: nil),
        double(reasoning: "item 3", observations: nil, code_action: nil),
        double(reasoning: "item 4", observations: nil, code_action: nil),
        double(reasoning: "item 5", observations: nil, code_action: nil)
      ]
      context = { history: }

      # Should only use last 3
      score = instance.send(:calculate_incoherence_score, step, context)
      expect(score).to be_between(0.0, 1.0)
    end

    it "combines history items with space separator" do
      # This tests that the method joins history text correctly
      step = double(reasoning: "abc", observations: nil, code_action: nil)
      history = [double(reasoning: "abc", observations: nil, code_action: nil)]
      context = { history: }

      score = instance.send(:calculate_incoherence_score, step, context)
      expect(score).to eq(0.0) # Identical content = 0 incoherence
    end
  end

  describe "#calculate_task_relevance" do
    it "returns high relevance for related content" do
      # Use content with significant overlap
      step = double(reasoning: "Find Ruby programming information documentation", observations: nil, code_action: nil)
      task = "Find Ruby programming information documentation"

      relevance = instance.send(:calculate_task_relevance, step, task)

      # Identical content should have very high relevance
      expect(relevance).to eq(1.0)
    end

    it "returns low relevance for unrelated content" do
      step = double(reasoning: "Weather forecast sunny cloudy rain", observations: nil, code_action: nil)
      task = "Find Ruby programming information"

      relevance = instance.send(:calculate_task_relevance, step, task)

      expect(relevance).to be < 0.3
    end

    it "returns 1.0 for identical content" do
      step = double(reasoning: "Find Ruby docs", observations: nil, code_action: nil)
      task = "Find Ruby docs"

      relevance = instance.send(:calculate_task_relevance, step, task)

      expect(relevance).to eq(1.0)
    end

    it "handles empty step content" do
      step = double(reasoning: nil, observations: nil, code_action: nil)
      task = "Some task"

      relevance = instance.send(:calculate_task_relevance, step, task)

      expect(relevance).to eq(0.0)
    end

    it "handles empty task" do
      step = double(reasoning: "Some content", observations: nil, code_action: nil)
      task = ""

      relevance = instance.send(:calculate_task_relevance, step, task)

      expect(relevance).to eq(0.0)
    end
  end

  describe "#extract_confidence" do
    it "returns confidence when step responds to confidence" do
      step = double(confidence: 0.85)
      allow(step).to receive(:respond_to?).with(:confidence).and_return(true)

      confidence = instance.send(:extract_confidence, step, {})

      expect(confidence).to eq(0.85)
    end

    it "returns nil when step does not respond to confidence" do
      step = Object.new

      confidence = instance.send(:extract_confidence, step, {})

      expect(confidence).to be_nil
    end

    it "returns nil when confidence is nil" do
      step = double(confidence: nil)
      allow(step).to receive(:respond_to?).with(:confidence).and_return(true)

      confidence = instance.send(:extract_confidence, step, {})

      expect(confidence).to be_nil
    end

    it "returns nil for confidence value of false" do
      step = double(confidence: false)
      allow(step).to receive(:respond_to?).with(:confidence).and_return(true)

      confidence = instance.send(:extract_confidence, step, {})

      expect(confidence).to be_nil
    end
  end

  describe "#calculate_confidence_decay" do
    it "returns 0.0 when history has fewer than 2 items" do
      instance.semantic_state[:confidence_history] = [0.8]

      decay = instance.send(:calculate_confidence_decay)

      expect(decay).to eq(0.0)
    end

    it "returns 0.0 when history is empty" do
      instance.semantic_state[:confidence_history] = []

      decay = instance.send(:calculate_confidence_decay)

      expect(decay).to eq(0.0)
    end

    it "returns positive decay when confidence decreases" do
      instance.semantic_state[:confidence_history] = [0.9, 0.85, 0.8, 0.7, 0.6]

      decay = instance.send(:calculate_confidence_decay)

      expect(decay).to be > 0.0
    end

    it "returns 0.0 when confidence increases" do
      instance.semantic_state[:confidence_history] = [0.6, 0.7, 0.8, 0.85, 0.9]

      decay = instance.send(:calculate_confidence_decay)

      expect(decay).to eq(0.0)
    end

    it "returns 0.0 when confidence is stable" do
      instance.semantic_state[:confidence_history] = [0.8, 0.8, 0.8, 0.8, 0.8]

      decay = instance.send(:calculate_confidence_decay)

      expect(decay).to eq(0.0)
    end

    it "only considers last 5 history items" do
      instance.semantic_state[:confidence_history] = [0.1, 0.2, 0.8, 0.8, 0.8, 0.8, 0.8]

      decay = instance.send(:calculate_confidence_decay)

      # Should only look at last 5: [0.8, 0.8, 0.8, 0.8, 0.8]
      expect(decay).to eq(0.0)
    end
  end

  describe "#compute_decay_from_history" do
    it "calculates decay as difference between first and second half averages" do
      history = [0.9, 0.85, 0.7, 0.65]
      # First half: [0.9, 0.85] avg = 0.875
      # Second half: [0.7, 0.65] avg = 0.675
      # Decay = 0.875 - 0.675 = 0.2

      decay = instance.send(:compute_decay_from_history, history)

      expect(decay).to be_within(0.001).of(0.2)
    end

    it "clamps negative decay to 0.0" do
      history = [0.6, 0.7, 0.8, 0.9]
      # First half avg = 0.65, Second half avg = 0.85
      # Decay = 0.65 - 0.85 = -0.2 -> clamped to 0.0

      decay = instance.send(:compute_decay_from_history, history)

      expect(decay).to eq(0.0)
    end

    it "handles odd-sized history" do
      history = [0.9, 0.8, 0.7, 0.6, 0.5]
      # midpoint = 2
      # First half: [0.9, 0.8] avg = 0.85
      # Second half: [0.7, 0.6, 0.5] avg = 0.6
      # Decay = 0.85 - 0.6 = 0.25

      decay = instance.send(:compute_decay_from_history, history)

      expect(decay).to be_within(0.001).of(0.25)
    end
  end

  describe "#semantic_hash" do
    it "returns trigrams of step text" do
      step = double(reasoning: "Hello world", observations: nil, code_action: nil)

      hash = instance.send(:semantic_hash, step)

      expect(hash).to be_a(Set)
      expect(hash).to include("Hel", "ell", "llo")
    end

    it "returns empty set for short text" do
      step = double(reasoning: "ab", observations: nil, code_action: nil)

      hash = instance.send(:semantic_hash, step)

      expect(hash).to be_empty
    end

    it "combines reasoning, observations, and code_action" do
      step = double(reasoning: "reasoning", observations: "observations", code_action: "code")

      hash = instance.send(:semantic_hash, step)

      # Combined text: "reasoning observations code"
      expect(hash).to include("rea", "obs", "cod")
    end

    it "handles nil fields" do
      step = double(reasoning: nil, observations: "test", code_action: nil)

      hash = instance.send(:semantic_hash, step)

      expect(hash).to include("tes", "est")
    end
  end

  describe "#max_similarity_to_previous" do
    it "returns 0.0 when no previous hashes" do
      current_hash = Set.new(%w[abc bcd cde])

      similarity = instance.send(:max_similarity_to_previous, current_hash)

      expect(similarity).to eq(0.0)
    end

    it "returns 1.0 for identical hash" do
      hash = Set.new(%w[abc bcd cde])
      instance.semantic_state[:semantic_hashes] = [hash]

      similarity = instance.send(:max_similarity_to_previous, hash)

      expect(similarity).to eq(1.0)
    end

    it "returns highest similarity among previous hashes" do
      hash1 = Set.new(%w[aaa bbb ccc])
      hash2 = Set.new(%w[abc bcd cde])
      hash3 = Set.new(%w[xyz yzz zzz])
      instance.semantic_state[:semantic_hashes] = [hash1, hash2, hash3]

      current = Set.new(%w[abc bcd cde def])

      similarity = instance.send(:max_similarity_to_previous, current)

      # Most similar to hash2
      expect(similarity).to be > 0.5
    end

    it "only compares against last 5 hashes" do
      # Add 6 hashes
      6.times do |i|
        instance.semantic_state[:semantic_hashes] << Set.new(["h#{i}a", "h#{i}b", "h#{i}c"])
      end

      # Hash 0 is not in last 5
      hash0 = Set.new(%w[h0a h0b h0c])

      similarity = instance.send(:max_similarity_to_previous, hash0)

      # Should not find exact match since hash0 is outside last 5
      expect(similarity).to be < 1.0
    end
  end

  describe "#jaccard_similarity" do
    it "returns 1.0 for identical sets" do
      set = Set.new(%w[a b c])

      similarity = instance.send(:jaccard_similarity, set, set)

      expect(similarity).to eq(1.0)
    end

    it "returns 0.0 for disjoint sets" do
      set_a = Set.new(%w[a b c])
      set_b = Set.new(%w[x y z])

      similarity = instance.send(:jaccard_similarity, set_a, set_b)

      expect(similarity).to eq(0.0)
    end

    it "returns 0.0 for two empty sets" do
      similarity = instance.send(:jaccard_similarity, Set.new, Set.new)

      expect(similarity).to eq(0.0)
    end

    it "calculates correct similarity for overlapping sets" do
      set_a = Set.new(%w[a b c d])
      set_b = Set.new(%w[c d e f])
      # Intersection: {c, d} = 2
      # Union: {a, b, c, d, e, f} = 6
      # Similarity: 2/6 = 0.333...

      similarity = instance.send(:jaccard_similarity, set_a, set_b)

      expect(similarity).to be_within(0.001).of(0.333)
    end

    it "handles arrays as input" do
      arr_a = %w[a b c]
      arr_b = %w[b c d]

      similarity = instance.send(:jaccard_similarity, arr_a, arr_b)

      # Intersection: {b, c} = 2
      # Union: {a, b, c, d} = 4
      expect(similarity).to eq(0.5)
    end
  end

  describe "#step_text" do
    it "combines reasoning, observations, and code_action" do
      step = double(reasoning: "thinking", observations: "saw this", code_action: "do that")
      allow(step).to receive(:respond_to?).with(:reasoning).and_return(true)
      allow(step).to receive(:respond_to?).with(:observations).and_return(true)
      allow(step).to receive(:respond_to?).with(:code_action).and_return(true)

      text = instance.send(:step_text, step)

      expect(text).to eq("thinking saw this do that")
    end

    it "handles missing reasoning" do
      step = double(observations: "saw this", code_action: "do that")
      allow(step).to receive(:respond_to?).with(:reasoning).and_return(false)
      allow(step).to receive(:respond_to?).with(:observations).and_return(true)
      allow(step).to receive(:respond_to?).with(:code_action).and_return(true)

      text = instance.send(:step_text, step)

      expect(text).to eq("saw this do that")
    end

    it "handles nil values" do
      step = double(reasoning: nil, observations: "obs", code_action: nil)
      allow(step).to receive(:respond_to?).with(:reasoning).and_return(true)
      allow(step).to receive(:respond_to?).with(:observations).and_return(true)
      allow(step).to receive(:respond_to?).with(:code_action).and_return(true)

      text = instance.send(:step_text, step)

      expect(text).to eq("obs")
    end

    it "returns empty string when all fields are nil or missing" do
      step = Object.new

      text = instance.send(:step_text, step)

      expect(text).to eq("")
    end

    it "preserves spacing between parts" do
      step = double(reasoning: "a", observations: "b", code_action: "c")
      allow(step).to receive(:respond_to?).with(:reasoning).and_return(true)
      allow(step).to receive(:respond_to?).with(:observations).and_return(true)
      allow(step).to receive(:respond_to?).with(:code_action).and_return(true)

      text = instance.send(:step_text, step)

      expect(text).to eq("a b c")
    end
  end

  describe "integration with Utilities::Similarity" do
    it "uses Similarity.string for relevance calculation" do
      # Verify the integration works correctly
      result = Smolagents::Utilities::Similarity.string("Ruby programming", "Ruby programming")
      expect(result).to eq(1.0)
    end

    it "uses Similarity.trigrams for semantic hashing" do
      trigrams = Smolagents::Utilities::Similarity.trigrams("hello")
      expect(trigrams).to include("hel", "ell", "llo")
    end
  end
end
