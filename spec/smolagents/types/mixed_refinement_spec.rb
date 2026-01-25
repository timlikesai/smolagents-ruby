require "smolagents"

RSpec.describe Smolagents::Types::MixedRefineConfig do
  describe ".default" do
    it "creates default config" do
      config = described_class.default
      expect(config.max_iterations).to eq(2)
      expect(config.feedback_source).to eq(:self)
      expect(config.min_confidence).to eq(0.8)
      expect(config.enabled).to be true
      expect(config.feedback_model).to be_nil
      expect(config.feedback_temperature).to eq(0.3)
      expect(config.cross_model_enabled).to be false
    end
  end

  describe ".with_feedback_model" do
    it "creates config with feedback model" do
      mock_model = double("model")
      config = described_class.with_feedback_model(mock_model, max_iterations: 3)
      expect(config.feedback_model).to eq(mock_model)
      expect(config.cross_model_enabled).to be true
      expect(config.max_iterations).to eq(3)
    end

    it "defaults to 2 iterations if not specified" do
      mock_model = double("model")
      config = described_class.with_feedback_model(mock_model)
      expect(config.max_iterations).to eq(2)
    end

    it "sets feedback source to :self" do
      mock_model = double("model")
      config = described_class.with_feedback_model(mock_model)
      expect(config.feedback_source).to eq(:self)
    end

    it "sets feedback temperature" do
      mock_model = double("model")
      config = described_class.with_feedback_model(mock_model)
      expect(config.feedback_temperature).to eq(0.3)
    end
  end

  describe ".disabled" do
    it "creates disabled config" do
      config = described_class.disabled
      expect(config.enabled).to be false
      expect(config.max_iterations).to eq(0)
      expect(config.min_confidence).to eq(1.0)
      expect(config.feedback_model).to be_nil
      expect(config.cross_model_enabled).to be false
    end
  end

  describe "#to_refine_config" do
    it "converts to RefineConfig" do
      config = described_class.default
      refine_config = config.to_refine_config
      expect(refine_config).to be_a(Smolagents::Types::RefineConfig)
      expect(refine_config.max_iterations).to eq(config.max_iterations)
      expect(refine_config.feedback_source).to eq(config.feedback_source)
      expect(refine_config.min_confidence).to eq(config.min_confidence)
      expect(refine_config.enabled).to eq(config.enabled)
    end

    it "preserves values during conversion" do
      mock_model = double("model")
      config = described_class.with_feedback_model(mock_model, max_iterations: 5)
      refine_config = config.to_refine_config
      expect(refine_config.max_iterations).to eq(5)
    end
  end

  describe "field accessors" do
    it "returns max_iterations" do
      config = described_class.default
      expect(config.max_iterations).to eq(2)
    end

    it "returns feedback_source" do
      config = described_class.default
      expect(config.feedback_source).to eq(:self)
    end

    it "returns min_confidence" do
      config = described_class.default
      expect(config.min_confidence).to eq(0.8)
    end

    it "returns enabled status" do
      config = described_class.default
      expect(config.enabled).to be true
    end

    it "returns feedback_model" do
      mock_model = double("model")
      config = described_class.with_feedback_model(mock_model)
      expect(config.feedback_model).to eq(mock_model)
    end

    it "returns feedback_temperature" do
      config = described_class.default
      expect(config.feedback_temperature).to eq(0.3)
    end

    it "returns cross_model_enabled" do
      config = described_class.default
      expect(config.cross_model_enabled).to be false
    end
  end

  describe "immutability" do
    it "is frozen" do
      config = described_class.default
      expect(config).to be_frozen
    end
  end
end

RSpec.describe Smolagents::Types::MixedRefinementResult do
  describe "field accessors" do
    it "stores original output" do
      result = described_class.new(
        original: "original text",
        refined: "refined text",
        iterations: 1,
        feedback_history: [],
        improved: true,
        confidence: 0.9,
        generation_model: "gpt-4",
        feedback_model_id: "gpt-4-turbo",
        cross_model: true
      )
      expect(result.original).to eq("original text")
    end

    it "stores refined output" do
      result = described_class.new(
        original: "text",
        refined: "better text",
        iterations: 1,
        feedback_history: [],
        improved: true,
        confidence: 0.9,
        generation_model: "model-a",
        feedback_model_id: "model-b",
        cross_model: true
      )
      expect(result.refined).to eq("better text")
    end

    it "stores iteration count" do
      result = described_class.new(
        original: "text",
        refined: "text",
        iterations: 3,
        feedback_history: [],
        improved: false,
        confidence: 0.7,
        generation_model: "model",
        feedback_model_id: "model",
        cross_model: false
      )
      expect(result.iterations).to eq(3)
    end

    it "stores feedback history" do
      history = %w[feedback1 feedback2]
      result = described_class.new(
        original: "text",
        refined: "text",
        iterations: 2,
        feedback_history: history,
        improved: true,
        confidence: 0.8,
        generation_model: "model",
        feedback_model_id: "model",
        cross_model: false
      )
      expect(result.feedback_history).to eq(history)
    end

    it "stores improved flag" do
      result = described_class.new(
        original: "text",
        refined: "text",
        iterations: 1,
        feedback_history: [],
        improved: true,
        confidence: 0.9,
        generation_model: "model",
        feedback_model_id: "model",
        cross_model: false
      )
      expect(result.improved).to be true
    end

    it "stores confidence score" do
      result = described_class.new(
        original: "text",
        refined: "text",
        iterations: 1,
        feedback_history: [],
        improved: false,
        confidence: 0.75,
        generation_model: "model",
        feedback_model_id: "model",
        cross_model: false
      )
      expect(result.confidence).to eq(0.75)
    end

    it "stores generation_model" do
      result = described_class.new(
        original: "text",
        refined: "text",
        iterations: 0,
        feedback_history: [],
        improved: false,
        confidence: 1.0,
        generation_model: "gpt-4",
        feedback_model_id: "claude-3",
        cross_model: true
      )
      expect(result.generation_model).to eq("gpt-4")
    end

    it "stores feedback_model_id" do
      result = described_class.new(
        original: "text",
        refined: "text",
        iterations: 1,
        feedback_history: [],
        improved: true,
        confidence: 0.85,
        generation_model: "gpt-4",
        feedback_model_id: "claude-3",
        cross_model: true
      )
      expect(result.feedback_model_id).to eq("claude-3")
    end

    it "stores cross_model flag" do
      result = described_class.new(
        original: "text",
        refined: "text",
        iterations: 0,
        feedback_history: [],
        improved: false,
        confidence: 1.0,
        generation_model: "model",
        feedback_model_id: "model",
        cross_model: false
      )
      expect(result.cross_model).to be false
    end
  end

  describe "#refined?" do
    it "returns true when iterations > 0" do
      result = described_class.new(
        original: "text",
        refined: "better",
        iterations: 2,
        feedback_history: [],
        improved: true,
        confidence: 0.9,
        generation_model: "a",
        feedback_model_id: "b",
        cross_model: true
      )
      expect(result.refined?).to be true
    end

    it "returns false when iterations == 0" do
      result = described_class.new(
        original: "text",
        refined: "text",
        iterations: 0,
        feedback_history: [],
        improved: false,
        confidence: 1.0,
        generation_model: "model",
        feedback_model_id: "model",
        cross_model: false
      )
      expect(result.refined?).to be false
    end
  end

  describe "#final" do
    it "returns refined when improved" do
      result = described_class.new(
        original: "original",
        refined: "refined",
        iterations: 1,
        feedback_history: [],
        improved: true,
        confidence: 0.9,
        generation_model: "a",
        feedback_model_id: "b",
        cross_model: false
      )
      expect(result.final).to eq("refined")
    end

    it "returns original when not improved" do
      result = described_class.new(
        original: "original",
        refined: "refined",
        iterations: 1,
        feedback_history: [],
        improved: false,
        confidence: 0.6,
        generation_model: "model",
        feedback_model_id: "model",
        cross_model: false
      )
      expect(result.final).to eq("original")
    end
  end

  describe ".from_refinement_result" do
    it "creates from RefinementResult with model info" do
      refinement = Smolagents::Types::RefinementResult.new(
        original: "text",
        refined: "better",
        iterations: 1,
        feedback_history: [],
        improved: true,
        confidence: 0.9
      )
      result = described_class.from_refinement_result(
        refinement,
        generation_model: "gpt-4",
        feedback_model_id: "gpt-4-turbo"
      )
      expect(result.original).to eq("text")
      expect(result.refined).to eq("better")
      expect(result.generation_model).to eq("gpt-4")
      expect(result.feedback_model_id).to eq("gpt-4-turbo")
    end

    it "sets cross_model based on model differences" do
      refinement = Smolagents::Types::RefinementResult.new(
        original: "text",
        refined: "text",
        iterations: 0,
        feedback_history: [],
        improved: false,
        confidence: 1.0
      )
      result = described_class.from_refinement_result(
        refinement,
        generation_model: "gpt-4",
        feedback_model_id: "claude-3"
      )
      expect(result.cross_model).to be true
    end

    it "sets cross_model false for same model" do
      refinement = Smolagents::Types::RefinementResult.new(
        original: "text",
        refined: "text",
        iterations: 1,
        feedback_history: [],
        improved: false,
        confidence: 0.8
      )
      result = described_class.from_refinement_result(
        refinement,
        generation_model: "gpt-4",
        feedback_model_id: "gpt-4"
      )
      expect(result.cross_model).to be false
    end
  end

  describe "immutability" do
    it "is frozen" do
      result = described_class.new(
        original: "text",
        refined: "text",
        iterations: 0,
        feedback_history: [],
        improved: false,
        confidence: 1.0,
        generation_model: "model",
        feedback_model_id: "model",
        cross_model: false
      )
      expect(result).to be_frozen
    end
  end
end
