RSpec.describe Smolagents::Testing::CallLog do
  subject(:log) { described_class.new }

  let(:tool_entry) do
    Smolagents::Testing::CallLogEntry.new(
      type: :tool_call,
      name: :search,
      args: { query: "Ruby" },
      result: "Found 10 results",
      timestamp: Time.now,
      metadata: { observation: "Search completed" }
    )
  end

  let(:step_entry) do
    Smolagents::Testing::CallLogEntry.new(
      type: :step,
      name: :step1,
      args: { step_number: 1 },
      result: "Step completed",
      timestamp: Time.now,
      metadata: { outcome: :success }
    )
  end

  describe "#entries" do
    it "starts empty" do
      expect(log.entries).to be_empty
    end
  end

  describe "#count" do
    it "returns zero for empty log" do
      expect(log.count).to eq(0)
    end

    it "returns entry count" do
      log.instance_variable_get(:@entries).push(tool_entry, step_entry)
      expect(log.count).to eq(2)
    end
  end

  describe "#tool_calls" do
    it "returns only tool call entries" do
      log.instance_variable_get(:@entries).push(tool_entry, step_entry)
      expect(log.tool_calls).to eq([tool_entry])
    end
  end

  describe "#model_calls" do
    let(:model_entry) do
      Smolagents::Testing::CallLogEntry.new(
        type: :model_call,
        name: :gpt4,
        args: {},
        result: nil,
        timestamp: Time.now,
        metadata: { duration_ms: 100 }
      )
    end

    it "returns only model call entries" do
      log.instance_variable_get(:@entries).push(tool_entry, model_entry, step_entry)
      expect(log.model_calls).to eq([model_entry])
    end
  end

  describe "#steps" do
    it "returns only step entries" do
      log.instance_variable_get(:@entries).push(tool_entry, step_entry)
      expect(log.steps).to eq([step_entry])
    end
  end

  describe "#include?" do
    before do
      log.instance_variable_get(:@entries).push(tool_entry, step_entry)
    end

    it "matches tool by name" do
      expect(log.include?(tool: :search)).to be true
      expect(log.include?(tool: :missing)).to be false
    end

    it "matches step by number" do
      expect(log.include?(step: 1)).to be true
      expect(log.include?(step: 2)).to be false
    end

    it "matches tool with args" do
      expect(log.include?(tool: :search, args: { query: "Ruby" })).to be true
      expect(log.include?(tool: :search, args: { query: "Python" })).to be false
    end

    it "matches tool with regex" do
      expect(log.include?(tool: :search, args: { query: /Ruby/ })).to be true
      expect(log.include?(tool: :search, args: { query: /Python/ })).to be false
    end
  end

  describe "#select" do
    before do
      log.instance_variable_get(:@entries).push(tool_entry, step_entry)
    end

    it "returns matching entries" do
      result = log.select(tool: :search)
      expect(result).to eq([tool_entry])
    end

    it "returns empty array when no matches" do
      result = log.select(tool: :missing)
      expect(result).to be_empty
    end
  end

  describe "#last" do
    before do
      log.instance_variable_get(:@entries).push(tool_entry, step_entry)
    end

    it "returns last entry without pattern" do
      expect(log.last).to eq(step_entry)
    end

    it "returns last matching entry with pattern" do
      expect(log.last(tool: :search)).to eq(tool_entry)
    end

    it "returns nil when no match" do
      expect(log.last(tool: :missing)).to be_nil
    end
  end

  describe "#clear!" do
    it "removes all entries" do
      log.instance_variable_get(:@entries).push(tool_entry, step_entry)
      log.clear!
      expect(log.entries).to be_empty
    end

    it "returns self for chaining" do
      expect(log.clear!).to eq(log)
    end
  end

  describe "#to_a" do
    it "returns entries as hashes" do
      log.instance_variable_get(:@entries).push(tool_entry)
      result = log.to_a
      expect(result).to be_an(Array)
      expect(result.first).to include(type: :tool_call, name: :search)
    end
  end

  describe "thread safety" do
    it "handles concurrent access" do
      threads = Array.new(10) do
        Thread.new do
          10.times do
            log.instance_variable_get(:@entries).push(tool_entry)
            log.count
            log.tool_calls
          end
        end
      end

      expect { threads.each(&:join) }.not_to raise_error
    end
  end
end

RSpec.describe Smolagents::Testing::CallLogEntry do
  describe ".from_event" do
    context "with ToolCallCompleted event" do
      let(:event) do
        Smolagents::Events::ToolCallCompleted.create(
          request_id: SecureRandom.uuid,
          tool_name: "search",
          result: "Found results",
          observation: "Search completed",
          is_final: false
        )
      end

      it "creates a tool_call entry" do
        entry = described_class.from_event(event)
        expect(entry.type).to eq(:tool_call)
        expect(entry.name).to eq(:search)
        expect(entry.result).to eq("Found results")
      end
    end

    context "with StepCompleted event" do
      let(:event) do
        Smolagents::Events::StepCompleted.create(
          step_number: 1,
          observations: "Done",
          outcome: :success
        )
      end

      it "creates a step entry" do
        entry = described_class.from_event(event)
        expect(entry.type).to eq(:step)
        expect(entry.name).to eq(:step1)
        expect(entry.args).to eq(step_number: 1)
        expect(entry.metadata).to include(outcome: :success)
      end
    end

    context "with unsupported event" do
      let(:event) { Smolagents::Events::TaskStarted.create(task: "test") }

      it "returns nil" do
        entry = described_class.from_event(event)
        expect(entry).to be_nil
      end
    end
  end

  describe "#matches?" do
    let(:entry) do
      described_class.new(
        type: :tool_call,
        name: :search,
        args: { query: "Ruby", limit: 10 },
        result: "Found",
        timestamp: Time.now,
        metadata: {}
      )
    end

    it "matches tool by name" do
      expect(entry.matches?(tool: :search)).to be true
      expect(entry.matches?(tool: :other)).to be false
    end

    it "matches tool with partial args" do
      expect(entry.matches?(tool: :search, args: { query: "Ruby" })).to be true
      expect(entry.matches?(tool: :search, args: { limit: 10 })).to be true
    end

    it "matches with regex" do
      expect(entry.matches?(tool: :search, args: { query: /Ru/ })).to be true
      expect(entry.matches?(tool: :search, args: { query: /Python/ })).to be false
    end
  end

  describe "predicates" do
    it "#tool_call? returns true for tool calls" do
      entry = described_class.new(type: :tool_call, name: :test, args: {},
                                  result: nil, timestamp: Time.now, metadata: {})
      expect(entry.tool_call?).to be true
      expect(entry.model_call?).to be false
      expect(entry.step?).to be false
    end

    it "#model_call? returns true for model calls" do
      entry = described_class.new(type: :model_call, name: :test, args: {},
                                  result: nil, timestamp: Time.now, metadata: {})
      expect(entry.model_call?).to be true
      expect(entry.tool_call?).to be false
    end

    it "#step? returns true for steps" do
      entry = described_class.new(type: :step, name: :step1, args: {},
                                  result: nil, timestamp: Time.now, metadata: {})
      expect(entry.step?).to be true
      expect(entry.tool_call?).to be false
    end
  end
end
