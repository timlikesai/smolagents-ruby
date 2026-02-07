require "spec_helper"

RSpec.describe Smolagents::Telemetry::CostTracker do
  let(:tracker) { described_class.new }

  describe "COST_PER_1K_TOKENS" do
    it "defines pricing for known models" do
      expect(described_class::COST_PER_1K_TOKENS["gpt-4"]).to eq(0.03)
      expect(described_class::COST_PER_1K_TOKENS["gpt-4-turbo"]).to eq(0.01)
      expect(described_class::COST_PER_1K_TOKENS["gpt-3.5-turbo"]).to eq(0.0015)
      expect(described_class::COST_PER_1K_TOKENS["claude-opus-4-5"]).to eq(0.015)
      expect(described_class::COST_PER_1K_TOKENS["claude-sonnet-4-5"]).to eq(0.003)
      expect(described_class::COST_PER_1K_TOKENS["claude-haiku-4"]).to eq(0.00025)
      expect(described_class::COST_PER_1K_TOKENS[:default]).to eq(0.01)
    end
  end

  describe "#track_cost" do
    it "calculates cost for known models" do
      event = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                         model_id: "gpt-4",
                                                         duration_ms: 1000,
                                                         token_usage: {
                                                           prompt_tokens: 100, completion_tokens: 50
                                                         },
                                                         outcome: :success)

      tracker.send(:track_cost, event)

      # (100 + 50) / 1000 * 0.03 = 0.0045
      expect(tracker.total_cost).to be_within(0.0001).of(0.0045)
    end

    it "uses default rate for unknown models" do
      event = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                         model_id: "unknown-model",
                                                         duration_ms: 1000,
                                                         token_usage: {
                                                           prompt_tokens: 100, completion_tokens: 100
                                                         },
                                                         outcome: :success)

      tracker.send(:track_cost, event)

      # (100 + 100) / 1000 * 0.01 = 0.002
      expect(tracker.total_cost).to be_within(0.0001).of(0.002)
    end

    it "handles events without token_usage" do
      event = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                         model_id: "gpt-4",
                                                         duration_ms: 1000,
                                                         token_usage: nil,
                                                         outcome: :success)

      tracker.send(:track_cost, event)

      expect(tracker.total_cost).to eq(0.0)
    end

    it "accumulates costs for multiple calls" do
      event1 = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                          model_id: "gpt-4",
                                                          duration_ms: 1000,
                                                          token_usage: {
                                                            prompt_tokens: 100, completion_tokens: 50
                                                          },
                                                          outcome: :success)

      event2 = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                          model_id: "gpt-4",
                                                          duration_ms: 1000,
                                                          token_usage: {
                                                            prompt_tokens: 200, completion_tokens: 100
                                                          },
                                                          outcome: :success)

      tracker.send(:track_cost, event1)
      tracker.send(:track_cost, event2)

      # (150 / 1000 * 0.03) + (300 / 1000 * 0.03) = 0.0045 + 0.009 = 0.0135
      expect(tracker.total_cost).to be_within(0.0001).of(0.0135)
    end
  end

  describe "#total_cost" do
    it "returns zero initially" do
      expect(tracker.total_cost).to eq(0.0)
    end

    it "sums costs across all models" do
      event1 = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                          model_id: "gpt-4",
                                                          duration_ms: 1000,
                                                          token_usage: {
                                                            prompt_tokens: 100, completion_tokens: 50
                                                          },
                                                          outcome: :success)

      event2 = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                          model_id: "gpt-3.5-turbo",
                                                          duration_ms: 1000,
                                                          token_usage: {
                                                            prompt_tokens: 200, completion_tokens: 100
                                                          },
                                                          outcome: :success)

      tracker.send(:track_cost, event1)
      tracker.send(:track_cost, event2)

      # gpt-4: 150 / 1000 * 0.03 = 0.0045
      # gpt-3.5-turbo: 300 / 1000 * 0.0015 = 0.00045
      # Total: 0.00495
      expect(tracker.total_cost).to be_within(0.0001).of(0.00495)
    end
  end

  describe "#cost_by_model" do
    it "returns empty hash initially" do
      expect(tracker.cost_by_model).to eq({})
    end

    it "tracks costs separately per model" do
      event1 = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                          model_id: "gpt-4",
                                                          duration_ms: 1000,
                                                          token_usage: {
                                                            prompt_tokens: 100, completion_tokens: 50
                                                          },
                                                          outcome: :success)

      event2 = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                          model_id: "gpt-3.5-turbo",
                                                          duration_ms: 1000,
                                                          token_usage: {
                                                            prompt_tokens: 200, completion_tokens: 100
                                                          },
                                                          outcome: :success)

      tracker.send(:track_cost, event1)
      tracker.send(:track_cost, event2)

      costs = tracker.cost_by_model

      expect(costs["gpt-4"]).to be_within(0.0001).of(0.0045)
      expect(costs["gpt-3.5-turbo"]).to be_within(0.0001).of(0.00045)
    end
  end

  describe "#reset!" do
    it "clears all tracked costs" do
      event = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                         model_id: "gpt-4",
                                                         duration_ms: 1000,
                                                         token_usage: {
                                                           prompt_tokens: 100, completion_tokens: 50
                                                         },
                                                         outcome: :success)

      tracker.send(:track_cost, event)
      expect(tracker.total_cost).to be > 0

      tracker.reset!

      expect(tracker.total_cost).to eq(0.0)
      expect(tracker.cost_by_model).to eq({})
    end

    it "returns self for chaining" do
      expect(tracker.reset!).to eq(tracker)
    end
  end

  describe "thread safety" do
    it "handles concurrent cost tracking", :slow do
      events = Array.new(100) do
        Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                   model_id: "gpt-4",
                                                   duration_ms: 1000,
                                                   token_usage: {
                                                     prompt_tokens: 10, completion_tokens: 10
                                                   },
                                                   outcome: :success)
      end

      threads = events.map do |event|
        Thread.new { tracker.send(:track_cost, event) }
      end

      threads.each(&:join)

      # 100 events * (20 tokens / 1000 * 0.03) = 100 * 0.0006 = 0.06
      expect(tracker.total_cost).to be_within(0.0001).of(0.06)
    end
  end

  describe "event subscription" do
    it "subscribes to model_generation completed events" do
      event = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                         model_id: "gpt-4",
                                                         duration_ms: 1000,
                                                         token_usage: {
                                                           prompt_tokens: 100, completion_tokens: 50
                                                         },
                                                         outcome: :success)

      tracker.consume(event)

      expect(tracker.total_cost).to be > 0
    end
  end
end

RSpec.describe Smolagents::Telemetry::RequestCostTracker do
  let(:request_id) { "req-123" }
  let(:tracker) { described_class.new(request_id:) }

  describe "#initialize" do
    it "sets request_id" do
      expect(tracker.request_id).to eq(request_id)
    end

    it "inherits CostTracker behavior" do
      expect(tracker).to respond_to(:total_cost)
      expect(tracker).to respond_to(:cost_by_model)
      expect(tracker).to respond_to(:reset!)
    end
  end

  describe "#finalize" do
    it "returns a hash with request details" do
      event = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                         model_id: "gpt-4",
                                                         duration_ms: 1000,
                                                         token_usage: {
                                                           prompt_tokens: 100, completion_tokens: 50
                                                         },
                                                         outcome: :success)

      tracker.send(:track_cost, event)

      report = tracker.finalize

      expect(report).to be_a(Hash)
      expect(report[:request_id]).to eq(request_id)
      expect(report[:total_cost]).to be_within(0.0001).of(0.0045)
      expect(report[:cost_by_model]).to be_a(Hash)
      expect(report[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T/)
    end

    it "includes all costs by model" do
      event1 = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                          model_id: "gpt-4",
                                                          duration_ms: 1000,
                                                          token_usage: {
                                                            prompt_tokens: 100, completion_tokens: 50
                                                          },
                                                          outcome: :success)

      event2 = Smolagents::Events::ModelGeneration.create(phase: :completed,
                                                          model_id: "gpt-3.5-turbo",
                                                          duration_ms: 1000,
                                                          token_usage: {
                                                            prompt_tokens: 200, completion_tokens: 100
                                                          },
                                                          outcome: :success)

      tracker.send(:track_cost, event1)
      tracker.send(:track_cost, event2)

      report = tracker.finalize

      expect(report[:cost_by_model]["gpt-4"]).to be_within(0.0001).of(0.0045)
      expect(report[:cost_by_model]["gpt-3.5-turbo"]).to be_within(0.0001).of(0.00045)
    end

    it "works with zero costs" do
      report = tracker.finalize

      expect(report[:request_id]).to eq(request_id)
      expect(report[:total_cost]).to eq(0.0)
      expect(report[:cost_by_model]).to eq({})
    end
  end
end
