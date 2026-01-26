require "spec_helper"

RSpec.describe Smolagents::Concerns::Monitorable::TokenTracking do
  subject(:tracker) { test_class.new }

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Monitorable::TokenTracking

      attr_accessor :logger
    end
  end

  let(:mock_logger) { double("Logger") }

  describe "#track_tokens" do
    it "adds tokens to running total" do
      usage1 = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      tracker.track_tokens(usage1)

      total = tracker.total_token_usage
      expect(total.input_tokens).to eq(100)
      expect(total.output_tokens).to eq(50)
    end

    it "accumulates multiple token usages" do
      usage1 = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      usage2 = Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)

      tracker.track_tokens(usage1)
      tracker.track_tokens(usage2)

      total = tracker.total_token_usage
      expect(total.input_tokens).to eq(150)
      expect(total.output_tokens).to eq(75)
    end

    it "returns updated total" do
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      result = tracker.track_tokens(usage)

      expect(result.input_tokens).to eq(100)
      expect(result.output_tokens).to eq(50)
    end

    it "logs token delta" do
      tracker.logger = mock_logger
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)

      logged_msg = nil
      allow(mock_logger).to receive(:debug) { |msg| logged_msg = msg }
      tracker.track_tokens(usage)

      expect(logged_msg).to include("Tokens:")
      expect(logged_msg).to include("+100")
      expect(logged_msg).to include("+50")
    end

    it "logs running total" do
      tracker.logger = mock_logger
      usage1 = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      usage2 = Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)

      logged_msg = nil
      allow(mock_logger).to receive(:debug) { |msg| logged_msg = msg }

      tracker.track_tokens(usage1)
      tracker.track_tokens(usage2)

      expect(logged_msg).to include("+50")
      expect(logged_msg).to include("150/75") # New totals
    end

    it "handles zero tokens" do
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 0, output_tokens: 0)
      result = tracker.track_tokens(usage)

      expect(result.input_tokens).to eq(0)
      expect(result.output_tokens).to eq(0)
    end

    it "handles large token counts" do
      usage1 = Smolagents::Types::TokenUsage.new(input_tokens: 1_000_000, output_tokens: 500_000)
      usage2 = Smolagents::Types::TokenUsage.new(input_tokens: 2_000_000, output_tokens: 1_000_000)

      tracker.track_tokens(usage1)
      result = tracker.track_tokens(usage2)

      expect(result.input_tokens).to eq(3_000_000)
      expect(result.output_tokens).to eq(1_500_000)
    end

    context "without logger" do
      it "does not raise error when logger is nil" do
        tracker.logger = nil
        usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)

        expect { tracker.track_tokens(usage) }.not_to raise_error
      end
    end
  end

  describe "#total_token_usage" do
    it "returns zero usage initially" do
      total = tracker.total_token_usage
      expect(total.input_tokens).to eq(0)
      expect(total.output_tokens).to eq(0)
    end

    it "returns accumulated totals" do
      usage1 = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      usage2 = Smolagents::Types::TokenUsage.new(input_tokens: 75, output_tokens: 25)

      tracker.track_tokens(usage1)
      tracker.track_tokens(usage2)

      total = tracker.total_token_usage
      expect(total.input_tokens).to eq(175)
      expect(total.output_tokens).to eq(75)
    end

    it "returns TokenUsage object" do
      total = tracker.total_token_usage
      expect(total).to be_a(Smolagents::Types::TokenUsage)
    end

    it "is consistent across multiple calls" do
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      tracker.track_tokens(usage)

      total1 = tracker.total_token_usage
      total2 = tracker.total_token_usage

      expect(total1.input_tokens).to eq(total2.input_tokens)
      expect(total1.output_tokens).to eq(total2.output_tokens)
    end
  end

  describe "#reset_tokens" do
    it "resets token count to zero" do
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 1000, output_tokens: 500)
      tracker.track_tokens(usage)

      expect(tracker.total_token_usage.input_tokens).to eq(1000)

      tracker.reset_tokens

      expect(tracker.total_token_usage.input_tokens).to eq(0)
      expect(tracker.total_token_usage.output_tokens).to eq(0)
    end

    it "returns zero usage" do
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      tracker.track_tokens(usage)

      result = tracker.reset_tokens

      expect(result.input_tokens).to eq(0)
      expect(result.output_tokens).to eq(0)
    end

    it "allows tracking after reset" do
      usage1 = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      tracker.track_tokens(usage1)
      tracker.reset_tokens

      usage2 = Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
      tracker.track_tokens(usage2)

      expect(tracker.total_token_usage.input_tokens).to eq(50)
      expect(tracker.total_token_usage.output_tokens).to eq(25)
    end

    it "can be called multiple times" do
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      tracker.track_tokens(usage)

      tracker.reset_tokens
      tracker.reset_tokens

      expect(tracker.total_token_usage.input_tokens).to eq(0)
    end
  end

  describe "private methods" do
    describe "#log_token_delta" do
      it "logs delta and total tokens" do
        tracker.logger = mock_logger
        delta = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
        total = Smolagents::Types::TokenUsage.new(input_tokens: 250, output_tokens: 150)

        logged_msg = nil
        allow(mock_logger).to receive(:debug) { |msg| logged_msg = msg }
        tracker.send(:log_token_delta, delta, total)

        expect(logged_msg).to include("+100")
        expect(logged_msg).to include("+50")
        expect(logged_msg).to include("250")
        expect(logged_msg).to include("150")
      end

      it "formats tokens correctly" do
        tracker.logger = mock_logger
        delta = Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
        total = Smolagents::Types::TokenUsage.new(input_tokens: 200, output_tokens: 100)

        allow(mock_logger).to receive(:debug)
        tracker.send(:log_token_delta, delta, total)
        expect(mock_logger).to have_received(:debug).with(%r{\+50/\+25.*200/100})
      end

      context "without logger" do
        it "does not raise error when logger is nil" do
          tracker.logger = nil
          delta = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
          total = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)

          expect do
            tracker.send(:log_token_delta, delta, total)
          end.not_to raise_error
        end
      end
    end
  end

  describe "integration" do
    it "tracks multi-step token usage" do
      tracker.logger = mock_logger
      allow(mock_logger).to receive(:debug)

      # First step
      usage1 = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      tracker.track_tokens(usage1)

      # Second step
      usage2 = Smolagents::Types::TokenUsage.new(input_tokens: 150, output_tokens: 75)
      tracker.track_tokens(usage2)

      # Third step
      usage3 = Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
      tracker.track_tokens(usage3)

      total = tracker.total_token_usage
      expect(total.input_tokens).to eq(300)
      expect(total.output_tokens).to eq(150)
    end

    it "can reset and track again" do
      usage1 = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      tracker.track_tokens(usage1)

      expect(tracker.total_token_usage.input_tokens).to eq(100)

      tracker.reset_tokens

      usage2 = Smolagents::Types::TokenUsage.new(input_tokens: 200, output_tokens: 100)
      tracker.track_tokens(usage2)

      expect(tracker.total_token_usage.input_tokens).to eq(200)
    end

    it "handles mixed token counts" do
      usages = [
        Smolagents::Types::TokenUsage.new(input_tokens: 10, output_tokens: 5),
        Smolagents::Types::TokenUsage.new(input_tokens: 20, output_tokens: 10),
        Smolagents::Types::TokenUsage.new(input_tokens: 30, output_tokens: 15),
        Smolagents::Types::TokenUsage.new(input_tokens: 40, output_tokens: 20)
      ]

      usages.each { |usage| tracker.track_tokens(usage) }

      total = tracker.total_token_usage
      expect(total.input_tokens).to eq(100)
      expect(total.output_tokens).to eq(50)
    end
  end
end
