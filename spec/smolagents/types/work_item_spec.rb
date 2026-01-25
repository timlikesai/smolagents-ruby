require "spec_helper"

RSpec.describe Smolagents::Types::WorkItem do
  describe "factory methods" do
    describe ".model_generate" do
      subject(:item) do
        described_class.model_generate(
          messages: [{ role: "user", content: "Hello" }],
          model_id: "gpt-4",
          priority: :high,
          temperature: 0.7
        )
      end

      it "creates a model_generate work item" do
        expect(item.type).to eq(:model_generate)
      end

      it "sets the priority" do
        expect(item.priority).to eq(:high)
      end

      it "generates a UUID" do
        expect(item.id).to match(/\A[0-9a-f-]{36}\z/)
      end

      it "stores payload with messages and model_id" do
        expect(item.payload[:messages]).to eq([{ role: "user", content: "Hello" }])
        expect(item.payload[:model_id]).to eq("gpt-4")
        expect(item.payload[:temperature]).to eq(0.7)
      end

      it "freezes the payload" do
        expect(item.payload).to be_frozen
      end

      it "sets created_at" do
        expect(item.created_at).to be_within(1).of(Time.now)
      end

      it "has no deadline by default" do
        expect(item.deadline).to be_nil
      end
    end

    describe ".tool_call" do
      subject(:item) do
        described_class.tool_call(
          tool_name: "search",
          args: { query: "Ruby" },
          priority: :normal
        )
      end

      it "creates a tool_call work item" do
        expect(item.type).to eq(:tool_call)
      end

      it "stores tool_name and args in payload" do
        expect(item.payload[:tool_name]).to eq("search")
        expect(item.payload[:args]).to eq({ query: "Ruby" })
      end
    end

    describe ".code_execution" do
      subject(:item) do
        described_class.code_execution(
          code: "puts 'hello'",
          execution_context: { timeout: 30 },
          priority: :low
        )
      end

      it "creates a code_execution work item" do
        expect(item.type).to eq(:code_execution)
      end

      it "stores code in payload" do
        expect(item.payload[:code]).to eq("puts 'hello'")
        expect(item.payload[:execution_context]).to eq({ timeout: 30 })
      end

      it "has low priority" do
        expect(item.priority).to eq(:low)
      end
    end

    describe ".sub_agent" do
      subject(:item) do
        described_class.sub_agent(
          task: "Research topic",
          agent_config: { persona: :researcher },
          priority: :critical,
          context: { parent_id: "parent-123" },
          deadline: Time.now + 60
        )
      end

      it "creates a sub_agent work item" do
        expect(item.type).to eq(:sub_agent)
      end

      it "stores task and agent_config" do
        expect(item.payload[:task]).to eq("Research topic")
        expect(item.payload[:agent_config]).to eq({ persona: :researcher })
      end

      it "has critical priority" do
        expect(item.priority).to eq(:critical)
      end

      it "stores context" do
        expect(item.context[:parent_id]).to eq("parent-123")
      end

      it "sets deadline" do
        expect(item.deadline).to be_within(1).of(Time.now + 60)
      end
    end
  end

  describe "type predicates" do
    it "returns true for matching type" do
      item = described_class.model_generate(messages: [], model_id: "test")
      expect(item.model_generate?).to be true
      expect(item.tool_call?).to be false
      expect(item.code_execution?).to be false
      expect(item.sub_agent?).to be false
    end

    it "identifies tool_call items" do
      item = described_class.tool_call(tool_name: "test", args: {})
      expect(item.tool_call?).to be true
    end

    it "identifies code_execution items" do
      item = described_class.code_execution(code: "")
      expect(item.code_execution?).to be true
    end

    it "identifies sub_agent items" do
      item = described_class.sub_agent(task: "", agent_config: {})
      expect(item.sub_agent?).to be true
    end
  end

  describe "priority predicates" do
    it "identifies critical priority" do
      item = described_class.model_generate(messages: [], model_id: "test", priority: :critical)
      expect(item.critical_priority?).to be true
      expect(item.elevated_priority?).to be true
    end

    it "identifies high priority" do
      item = described_class.model_generate(messages: [], model_id: "test", priority: :high)
      expect(item.high_priority?).to be true
      expect(item.elevated_priority?).to be true
    end

    it "identifies normal priority" do
      item = described_class.model_generate(messages: [], model_id: "test", priority: :normal)
      expect(item.normal_priority?).to be true
      expect(item.elevated_priority?).to be false
    end

    it "identifies low priority" do
      item = described_class.model_generate(messages: [], model_id: "test", priority: :low)
      expect(item.low_priority?).to be true
      expect(item.elevated_priority?).to be false
    end
  end

  describe "#wait_time" do
    it "calculates time since creation", :slow do
      item = described_class.model_generate(messages: [], model_id: "test")
      sleep 0.01 # rubocop:disable Smolagents/NoSleep -- needed to test elapsed time
      expect(item.wait_time).to be >= 0.01
    end
  end

  describe "#expired?" do
    it "returns false when no deadline" do
      item = described_class.model_generate(messages: [], model_id: "test")
      expect(item.expired?).to be false
    end

    it "returns false when deadline not passed" do
      item = described_class.model_generate(
        messages: [],
        model_id: "test",
        deadline: Time.now + 60
      )
      expect(item.expired?).to be false
    end

    it "returns true when deadline passed" do
      item = described_class.model_generate(
        messages: [],
        model_id: "test",
        deadline: Time.now - 1
      )
      expect(item.expired?).to be true
    end
  end

  describe "#time_remaining" do
    it "returns nil when no deadline" do
      item = described_class.model_generate(messages: [], model_id: "test")
      expect(item.time_remaining).to be_nil
    end

    it "returns positive time when deadline in future" do
      item = described_class.model_generate(
        messages: [],
        model_id: "test",
        deadline: Time.now + 60
      )
      expect(item.time_remaining).to be > 0
    end

    it "returns negative time when deadline passed" do
      item = described_class.model_generate(
        messages: [],
        model_id: "test",
        deadline: Time.now - 10
      )
      expect(item.time_remaining).to be < 0
    end
  end

  describe "pattern matching" do
    it "supports deconstruction" do
      item = described_class.model_generate(
        messages: [{ role: "user", content: "test" }],
        model_id: "gpt-4"
      )

      # rubocop:disable RSpec/DescribedClass -- pattern matching requires literal class
      case item
      in Smolagents::Types::WorkItem[type: :model_generate, payload: { model_id: }]
        expect(model_id).to eq("gpt-4")
      else
        raise "Pattern did not match"
      end
      # rubocop:enable RSpec/DescribedClass
    end
  end
end
