require "spec_helper"

RSpec.describe Smolagents::Concerns::Compression::Strategy do
  let(:strategy_class) do
    Class.new do
      include Smolagents::Concerns::Compression::Strategy

      def self.strategy_name = :test_strategy
    end
  end

  let(:instance) { strategy_class.new }

  let(:memory) do
    double("Memory", token_usage_percent: 0.8)
  end

  describe ".strategy_name" do
    it "raises NotImplementedError when not defined" do
      bare_class = Class.new do
        include Smolagents::Concerns::Compression::Strategy
      end

      expect { bare_class.strategy_name }.to raise_error(NotImplementedError)
    end

    it "returns strategy name when defined" do
      expect(strategy_class.strategy_name).to eq(:test_strategy)
    end
  end

  describe "#should_compress?" do
    context "when compression is enabled" do
      let(:config) { Smolagents::Types::CompressionConfig.default }

      it "returns true when usage exceeds threshold" do
        allow(memory).to receive(:token_usage_percent).and_return(0.8)

        expect(instance.should_compress?(memory, config)).to be true
      end

      it "returns true when usage equals threshold" do
        allow(memory).to receive(:token_usage_percent).and_return(0.75)

        expect(instance.should_compress?(memory, config)).to be true
      end

      it "returns false when usage is below threshold" do
        allow(memory).to receive(:token_usage_percent).and_return(0.5)

        expect(instance.should_compress?(memory, config)).to be false
      end
    end

    context "when compression is disabled" do
      let(:config) { Smolagents::Types::CompressionConfig.disabled }

      it "returns false regardless of usage" do
        allow(memory).to receive(:token_usage_percent).and_return(0.99)

        expect(instance.should_compress?(memory, config)).to be false
      end
    end
  end

  describe "#compress" do
    it "raises NotImplementedError in base module" do
      expect { instance.compress([], budget: 200) }.to raise_error(NotImplementedError)
    end
  end

  describe "#estimate_quality" do
    it "returns compression ratio as quality" do
      # Original steps with longer content
      original_steps = [
        double("Step", to_s: "x" * 100),
        double("Step", to_s: "x" * 100)
      ]
      summary_step = double("SummaryStep", to_s: "Short summary")

      quality = instance.estimate_quality(original_steps, summary_step)

      expect(quality).to be_between(0.0, 1.0)
      expect(quality).to be > 0.5
    end

    it "returns 1.0 when original tokens is zero" do
      original_steps = []
      summary_step = double("SummaryStep", to_s: "Summary")

      quality = instance.estimate_quality(original_steps, summary_step)

      expect(quality).to eq(1.0)
    end

    it "returns high quality for significant compression" do
      # Original steps are much longer than summary
      original_steps = [
        double("Step", to_s: "x" * 200),
        double("Step", to_s: "x" * 200)
      ]
      summary_step = double("SummaryStep", to_s: "x" * 10)

      quality = instance.estimate_quality(original_steps, summary_step)

      expect(quality).to be > 0.9
    end
  end
end
