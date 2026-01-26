RSpec.describe Smolagents::Types::SubAgentRecord do
  let(:token_usage) { Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50) }
  let(:timestamp) { Time.now.utc.iso8601 }

  describe "attributes" do
    it "has all required fields" do
      record = described_class.new(
        agent_name: "researcher",
        token_usage: token_usage,
        step_count: 3,
        duration: 2.5,
        outcome: :success,
        timestamp: timestamp
      )

      expect(record.agent_name).to eq("researcher")
      expect(record.token_usage).to eq(token_usage)
      expect(record.step_count).to eq(3)
      expect(record.duration).to eq(2.5)
      expect(record.outcome).to eq(:success)
      expect(record.timestamp).to eq(timestamp)
    end
  end

  describe "#success?" do
    it "returns true when outcome is :success" do
      record = described_class.new(
        agent_name: "helper",
        token_usage: token_usage,
        step_count: 1,
        duration: 1.0,
        outcome: :success,
        timestamp: timestamp
      )

      expect(record.success?).to be true
    end

    it "returns false for other outcomes" do
      %i[error failure timeout].each do |outcome|
        record = described_class.new(
          agent_name: "helper",
          token_usage: token_usage,
          step_count: 1,
          duration: 1.0,
          outcome: outcome,
          timestamp: timestamp
        )

        expect(record.success?).to be false
      end
    end
  end

  describe "#error?" do
    it "returns true when outcome is :error" do
      record = described_class.new(
        agent_name: "helper",
        token_usage: token_usage,
        step_count: 1,
        duration: 1.0,
        outcome: :error,
        timestamp: timestamp
      )

      expect(record.error?).to be true
    end

    it "returns false for other outcomes" do
      %i[success failure timeout].each do |outcome|
        record = described_class.new(
          agent_name: "helper",
          token_usage: token_usage,
          step_count: 1,
          duration: 1.0,
          outcome: outcome,
          timestamp: timestamp
        )

        expect(record.error?).to be false
      end
    end
  end

  describe "pattern matching with deconstruct_keys" do
    it "matches on agent_name" do
      record = described_class.new(
        agent_name: "researcher",
        token_usage: token_usage,
        step_count: 2,
        duration: 1.5,
        outcome: :success,
        timestamp: timestamp
      )

      matched = case record
                in agent_name: "researcher"
                  "researcher found"
                else
                  "other"
                end

      expect(matched).to eq("researcher found")
    end

    it "matches on outcome" do
      record = described_class.new(
        agent_name: "helper",
        token_usage: token_usage,
        step_count: 1,
        duration: 1.0,
        outcome: :error,
        timestamp: timestamp
      )

      matched = case record
                in outcome: :error
                  "error"
                else
                  "ok"
                end

      expect(matched).to eq("error")
    end

    it "matches on multiple fields" do
      record = described_class.new(
        agent_name: "writer",
        token_usage: token_usage,
        step_count: 5,
        duration: 3.0,
        outcome: :success,
        timestamp: timestamp
      )

      matched = case record
                in agent_name: "writer", step_count: 5
                  "writer with 5 steps"
                else
                  "other"
                end

      expect(matched).to eq("writer with 5 steps")
    end
  end

  describe "serialization" do
    it "converts to hash" do
      record = described_class.new(
        agent_name: "researcher",
        token_usage: token_usage,
        step_count: 3,
        duration: 2.5,
        outcome: :success,
        timestamp: timestamp
      )

      hash = record.to_h

      expect(hash[:agent_name]).to eq("researcher")
      expect(hash[:step_count]).to eq(3)
      expect(hash[:duration]).to eq(2.5)
      expect(hash[:outcome]).to eq(:success)
      expect(hash[:timestamp]).to eq(timestamp)
    end
  end

  describe "immutability" do
    it "is frozen" do
      record = described_class.new(
        agent_name: "helper",
        token_usage: token_usage,
        step_count: 1,
        duration: 1.0,
        outcome: :success,
        timestamp: timestamp
      )

      expect(record).to be_frozen
    end
  end
end
