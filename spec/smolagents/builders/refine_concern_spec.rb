RSpec.describe Smolagents::Builders::RefineConcern do
  let(:builder) { Smolagents::Builders::AgentBuilder.create }

  describe "#refine" do
    context "with no arguments (defaults)" do
      it "enables refinement with default config" do
        result = builder.refine
        config = result.config[:refine_config]

        expect(config).to be_a(Smolagents::Types::RefineConfig)
        expect(config.enabled).to be true
        expect(config.max_iterations).to eq(3)
        expect(config.feedback_source).to eq(:execution)
        expect(config.min_confidence).to eq(0.8)
      end
    end

    context "with integer argument" do
      it "sets max_iterations" do
        result = builder.refine(5)
        config = result.config[:refine_config]

        expect(config.enabled).to be true
        expect(config.max_iterations).to eq(5)
      end
    end

    context "with false" do
      it "disables refinement" do
        result = builder.refine(false)
        config = result.config[:refine_config]

        expect(config.enabled).to be false
      end
    end

    context "with :disabled symbol" do
      it "disables refinement" do
        result = builder.refine(:disabled)
        config = result.config[:refine_config]

        expect(config.enabled).to be false
      end
    end

    context "with keyword arguments" do
      it "accepts max_iterations keyword" do
        result = builder.refine(max_iterations: 7)
        config = result.config[:refine_config]

        expect(config.max_iterations).to eq(7)
      end

      it "accepts feedback keyword" do
        result = builder.refine(feedback: :self)
        config = result.config[:refine_config]

        expect(config.feedback_source).to eq(:self)
      end

      it "accepts min_confidence keyword" do
        result = builder.refine(min_confidence: 0.9)
        config = result.config[:refine_config]

        expect(config.min_confidence).to eq(0.9)
      end

      it "accepts combined keywords" do
        result = builder.refine(max_iterations: 2, feedback: :evaluation, min_confidence: 0.7)
        config = result.config[:refine_config]

        expect(config.max_iterations).to eq(2)
        expect(config.feedback_source).to eq(:evaluation)
        expect(config.min_confidence).to eq(0.7)
      end
    end

    context "with invalid argument" do
      it "raises ArgumentError" do
        expect { builder.refine("invalid") }.to raise_error(ArgumentError, /Invalid refine argument/)
      end
    end

    it "returns a new builder (immutable)" do
      result = builder.refine
      expect(result).not_to be(builder)
      expect(builder.config[:refine_config]).to be_nil
    end
  end
end
