require "smolagents"

RSpec.describe Smolagents::Concerns::CostAccounting do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::CostAccounting

      def initialize(budget: nil)
        initialize_cost_accounting(budget:)
      end
    end
  end

  describe "unlimited budget" do
    let(:tracker) { test_class.new }

    it "has nil token_budget" do
      expect(tracker.token_budget).to be_nil
    end

    it "starts with zero tokens consumed" do
      expect(tracker.tokens_consumed).to eq(0)
    end

    it "returns nil for remaining_token_budget" do
      expect(tracker.remaining_token_budget).to be_nil
    end

    it "reports token_budget_exceeded? as false" do
      expect(tracker).not_to be_token_budget_exceeded
    end

    it "does not raise on check_token_budget!" do
      expect { tracker.check_token_budget! }.not_to raise_error
    end
  end

  describe "budget set" do
    let(:tracker) { test_class.new(budget: 1000) }

    it "tracks the configured budget" do
      expect(tracker.token_budget).to eq(1000)
    end

    it "decreases remaining as tokens are consumed" do
      tracker.consume_tokens(300)
      expect(tracker.remaining_token_budget).to eq(700)

      tracker.consume_tokens(200)
      expect(tracker.remaining_token_budget).to eq(500)
    end

    it "reports exceeded when consumed equals budget" do
      tracker.consume_tokens(1000)
      expect(tracker).to be_token_budget_exceeded
    end

    it "reports exceeded when consumed exceeds budget" do
      tracker.consume_tokens(1500)
      expect(tracker).to be_token_budget_exceeded
    end

    it "floors remaining at zero" do
      tracker.consume_tokens(2000)
      expect(tracker.remaining_token_budget).to eq(0)
    end
  end

  describe "#consume_tokens" do
    let(:tracker) { test_class.new(budget: 10_000) }

    it "accepts Integer" do
      tracker.consume_tokens(500)
      expect(tracker.tokens_consumed).to eq(500)
    end

    it "accepts Hash with :total_tokens" do
      tracker.consume_tokens({ total_tokens: 250 })
      expect(tracker.tokens_consumed).to eq(250)
    end

    it "defaults to 0 for Hash without :total_tokens" do
      tracker.consume_tokens({ input_tokens: 100 })
      expect(tracker.tokens_consumed).to eq(0)
    end

    it "accepts object responding to total_tokens" do
      usage = double("Usage", total_tokens: 750)
      tracker.consume_tokens(usage)
      expect(tracker.tokens_consumed).to eq(750)
    end

    it "defaults to 0 for unrecognized object" do
      tracker.consume_tokens(Object.new)
      expect(tracker.tokens_consumed).to eq(0)
    end

    it "is a no-op for nil" do
      tracker.consume_tokens(nil)
      expect(tracker.tokens_consumed).to eq(0)
    end

    it "accumulates across multiple calls" do
      tracker.consume_tokens(100)
      tracker.consume_tokens({ total_tokens: 200 })
      tracker.consume_tokens(double("Usage", total_tokens: 300))
      expect(tracker.tokens_consumed).to eq(600)
    end
  end

  describe "#check_token_budget!" do
    it "returns nil when under budget" do
      tracker = test_class.new(budget: 1000)
      tracker.consume_tokens(500)
      expect(tracker.check_token_budget!).to be_nil
    end

    it "returns nil when no budget configured" do
      tracker = test_class.new
      tracker.consume_tokens(999_999)
      expect(tracker.check_token_budget!).to be_nil
    end

    it "raises TokenBudgetExceeded when exceeded" do
      tracker = test_class.new(budget: 100)
      tracker.consume_tokens(150)

      expect { tracker.check_token_budget! }
        .to raise_error(Smolagents::Errors::TokenBudgetExceeded) do |error|
          expect(error.message).to include("150/100")
          expect(error.budget).to eq(100)
          expect(error.consumed).to eq(150)
        end
    end

    it "raises TokenBudgetExceeded when exactly at budget" do
      tracker = test_class.new(budget: 500)
      tracker.consume_tokens(500)

      expect { tracker.check_token_budget! }
        .to raise_error(Smolagents::Errors::TokenBudgetExceeded)
    end
  end
end
