require "spec_helper"

RSpec.describe Smolagents::Events do
  describe Smolagents::Events::ToolCallRequested do
    describe ".create" do
      it "creates event with unique id" do
        event = described_class.create(tool_name: "search", args: { query: "test" })

        expect(event.id).to be_a(String)
        expect(event.id.length).to eq(36) # UUID format
      end

      it "sets created_at to current time" do
        event = described_class.create(tool_name: "search", args: {})

        expect(event.created_at).to be_within(0.1).of(Time.now)
      end

      it "freezes args" do
        event = described_class.create(tool_name: "search", args: { query: "test" })

        expect(event.args).to be_frozen
      end
    end
  end

  describe Smolagents::Events::ToolCallCompleted do
    describe ".create" do
      it "creates completed event with result" do
        event = described_class.create(
          request_id: "req-123",
          tool_name: "search",
          result: { data: "test" },
          observation: "Search returned test"
        )

        expect(event.request_id).to eq("req-123")
        expect(event.result).to eq({ data: "test" })
        expect(event.observation).to eq("Search returned test")
        expect(event.is_final).to be false
      end

      it "supports final answer flag" do
        event = described_class.create(
          request_id: "req-123",
          tool_name: "final_answer",
          result: "42",
          observation: "Final answer: 42",
          is_final: true
        )

        expect(event.is_final).to be true
      end
    end
  end

  describe Smolagents::Events::StepCompleted do
    describe ".create" do
      it "creates step event with outcome" do
        event = described_class.create(step_number: 1, outcome: :success)

        expect(event.step_number).to eq(1)
        expect(event.success?).to be true
        expect(event.error?).to be false
      end

      it "supports different outcomes" do
        expect(described_class.create(step_number: 1, outcome: :error).error?).to be true
        expect(described_class.create(step_number: 1, outcome: :final_answer).final_answer?).to be true
      end
    end
  end

  describe Smolagents::Events::ErrorOccurred do
    describe ".create" do
      it "captures error details" do
        error = StandardError.new("Something went wrong")
        event = described_class.create(error:, context: { step: 1 })

        expect(event.error_class).to eq("StandardError")
        expect(event.error_message).to eq("Something went wrong")
        expect(event.context).to eq({ step: 1 })
        expect(event.recoverable?).to be false
        expect(event.fatal?).to be true
      end

      it "supports recoverable errors" do
        error = StandardError.new("Transient failure")
        event = described_class.create(error:, recoverable: true)

        expect(event.recoverable?).to be true
        expect(event.fatal?).to be false
      end
    end
  end

  describe Smolagents::Events::TaskCompleted do
    describe ".create" do
      it "creates completion event" do
        event = described_class.create(outcome: :success, output: "42", steps_taken: 3)

        expect(event.success?).to be true
        expect(event.output).to eq("42")
        expect(event.steps_taken).to eq(3)
      end

      it "supports different outcomes" do
        expect(described_class.create(outcome: :max_steps_reached, output: nil, steps_taken: 10).max_steps?).to be true
        expect(described_class.create(outcome: :error, output: nil, steps_taken: 2).error?).to be true
      end
    end
  end

  describe Smolagents::Events::SubAgentLaunched do
    describe ".create" do
      it "creates launch event" do
        event = described_class.create(agent_name: "researcher", task: "Find info")

        expect(event.agent_name).to eq("researcher")
        expect(event.task).to eq("Find info")
        expect(event.parent_id).to be_nil
      end
    end
  end

  describe Smolagents::Events::SubAgentCompleted do
    describe ".create" do
      it "creates completion event" do
        event = described_class.create(
          launch_id: "launch-123",
          agent_name: "researcher",
          outcome: :success,
          output: "Found it"
        )

        expect(event.success?).to be true
        expect(event.output).to eq("Found it")
      end

      it "captures errors" do
        event = described_class.create(
          launch_id: "launch-123",
          agent_name: "researcher",
          outcome: :error,
          error: "Failed"
        )

        expect(event.error?).to be true
        expect(event.error).to eq("Failed")
      end
    end
  end
end
