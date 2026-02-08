require "smolagents"

RSpec.describe Smolagents::Concerns::Confidence::Calibration do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Confidence::Calibration
    end
  end

  let(:instance) { test_class.new }

  # Simple test scorer that returns syntactic-only estimate
  let(:simple_scorer) do
    Class.new do
      def self.score(tool_call, tools)
        tool = tools[tool_call.name]
        score = tool ? 0.9 : 0.2
        Smolagents::Types::ConfidenceEstimate.syntactic_only(score)
      end
    end
  end

  let(:mock_tool_call) do
    double("ToolCall", name: "search", arguments: { query: "test" })
  end

  let(:tools) do
    { "search" => double("Tool") }
  end

  describe "ClassMethods" do
    describe ".scorers" do
      it "returns empty hash by default" do
        fresh_class = Class.new { include Smolagents::Concerns::Confidence::Calibration }

        expect(fresh_class.scorers).to eq({})
      end
    end

    describe ".register_scorer" do
      it "adds scorer to registry" do
        test_class.register_scorer(:test, simple_scorer)

        expect(test_class.scorers[:test]).to eq(simple_scorer)
      end
    end

    describe ".scorer_for" do
      before do
        test_class.register_scorer(:default, simple_scorer)
        test_class.register_scorer(:custom, simple_scorer)
      end

      it "returns registered scorer by name" do
        expect(test_class.scorer_for(:custom)).to eq(simple_scorer)
      end

      it "falls back to default when name not found" do
        expect(test_class.scorer_for(:unknown)).to eq(simple_scorer)
      end

      it "returns nil when no default exists" do
        fresh_class = Class.new { include Smolagents::Concerns::Confidence::Calibration }

        expect(fresh_class.scorer_for(:unknown)).to be_nil
      end
    end
  end

  describe "#score_confidence" do
    before do
      test_class.register_scorer(:default, simple_scorer)
    end

    it "uses default scorer by default" do
      result = instance.score_confidence(mock_tool_call, tools)

      expect(result).to be_a(Smolagents::Types::ConfidenceEstimate)
      expect(result.blended).to eq(0.9)
    end

    it "uses specified scorer" do
      custom_scorer = Class.new do
        def self.score(_call, _tools)
          Smolagents::Types::ConfidenceEstimate.syntactic_only(0.5)
        end
      end
      test_class.register_scorer(:custom, custom_scorer)

      result = instance.score_confidence(mock_tool_call, tools, scorer: :custom)

      expect(result.blended).to eq(0.5)
    end

    it "raises ArgumentError when scorer not found and no default" do
      # Create a fresh class with no registered scorers
      fresh_class = Class.new do
        include Smolagents::Concerns::Confidence::Calibration
      end
      fresh_instance = fresh_class.new

      expect do
        fresh_instance.score_confidence(mock_tool_call, tools, scorer: :nonexistent)
      end.to raise_error(ArgumentError, /Unknown scorer: nonexistent/)
    end

    it "falls back to default scorer when unknown scorer requested" do
      result = instance.score_confidence(mock_tool_call, tools, scorer: :nonexistent)

      expect(result).to be_a(Smolagents::Types::ConfidenceEstimate)
    end
  end

  describe "#blend_confidence" do
    let(:estimate1) { Smolagents::Types::ConfidenceEstimate.syntactic_only(0.8) }
    let(:estimate2) { Smolagents::Types::ConfidenceEstimate.syntactic_only(0.6) }
    let(:estimate3) { Smolagents::Types::ConfidenceEstimate.syntactic_only(0.4) }

    it "returns zero estimate for empty scores" do
      result = instance.blend_confidence([])

      expect(result.blended).to eq(0.0)
    end

    it "uses equal weights by default" do
      # (0.8 + 0.6) / 2 = 0.7
      result = instance.blend_confidence([estimate1, estimate2])

      expect(result.blended).to be_within(0.001).of(0.7)
    end

    it "accepts custom weights" do
      # 0.8 * 0.7 + 0.6 * 0.3 = 0.56 + 0.18 = 0.74
      result = instance.blend_confidence([estimate1, estimate2], weights: [0.7, 0.3])

      expect(result.blended).to be_within(0.001).of(0.74)
    end

    it "averages syntactic scores" do
      result = instance.blend_confidence([estimate1, estimate2, estimate3])

      # (0.8 + 0.6 + 0.4) / 3 = 0.6
      expect(result.syntactic).to be_within(0.001).of(0.6)
    end

    it "records component count in factors" do
      result = instance.blend_confidence([estimate1, estimate2])

      expect(result.factors[:component_count]).to eq(2)
    end

    it "clamps result to valid range" do
      high = Smolagents::Types::ConfidenceEstimate.syntactic_only(1.0)
      result = instance.blend_confidence([high, high], weights: [1.0, 1.0])

      expect(result.blended).to eq(1.0)
    end

    it "returns ConfidenceEstimate" do
      result = instance.blend_confidence([estimate1])

      expect(result).to be_a(Smolagents::Types::ConfidenceEstimate)
    end
  end
end
