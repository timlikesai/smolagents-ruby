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
        before = Time.now
        event = described_class.create(tool_name: "search", args: {})
        after = Time.now

        expect(event.created_at).to be_between(before, after)
      end

      it "freezes args" do
        event = described_class.create(tool_name: "search", args: { query: "test" })

        expect(event.args).to be_frozen
      end

      it "is immediately ready when no due_at" do
        event = described_class.create(tool_name: "search", args: {})

        expect(event.ready?).to be true
        expect(event.immediate?).to be true
        expect(event.scheduled?).to be false
      end

      it "respects due_at for scheduled events" do
        future = Time.now + 60
        event = described_class.create(tool_name: "search", args: {}, due_at: future)

        expect(event.ready?).to be false
        expect(event.scheduled?).to be true
        expect(event.wait_time).to be_within(1).of(60)
      end
    end

    describe "#past_due?" do
      it "returns false when not yet due" do
        future = Time.now + 60
        event = described_class.create(tool_name: "search", args: {}, due_at: future)

        expect(event.past_due?).to be false
      end

      it "returns false when recently due" do
        past = Time.now - 30
        event = described_class.create(tool_name: "search", args: {}, due_at: past)

        expect(event.past_due?(threshold: 60)).to be false
      end

      it "returns true when past threshold" do
        past = Time.now - 90
        event = described_class.create(tool_name: "search", args: {}, due_at: past)

        expect(event.past_due?(threshold: 60)).to be true
      end
    end
  end

  describe Smolagents::Events::RateLimitHit do
    let(:original_request) do
      Smolagents::Events::ToolCallRequested.create(tool_name: "search", args: { query: "test" })
    end

    describe ".create" do
      it "calculates due_at from created_at + retry_after" do
        before = Time.now
        event = described_class.create(
          tool_name: "search",
          retry_after: 5.0,
          original_request:
        )
        after = Time.now

        expect(event.due_at).to be_between(before + 5.0, after + 5.0)
      end

      it "is not immediately ready" do
        event = described_class.create(
          tool_name: "search",
          retry_after: 5.0,
          original_request:
        )

        expect(event.ready?).to be false
      end

      it "preserves original request" do
        event = described_class.create(
          tool_name: "search",
          retry_after: 5.0,
          original_request:
        )

        expect(event.original_request).to eq(original_request)
      end
    end

    describe "#wait_time" do
      it "returns time until due" do
        event = described_class.create(
          tool_name: "search",
          retry_after: 10.0,
          original_request:
        )

        expect(event.wait_time).to be_within(1).of(10)
      end

      it "returns 0 when already due" do
        event = described_class.new(
          id: "test",
          tool_name: "search",
          retry_after: 0.0,
          original_request:,
          created_at: Time.now - 1
        )

        expect(event.wait_time).to eq(0.0)
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
        expect(described_class.create(step_number: 1, outcome: :rate_limited).rate_limited?).to be true
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
        expect(described_class.create(outcome: :max_steps, output: nil, steps_taken: 10).max_steps?).to be true
        expect(described_class.create(outcome: :error, output: nil, steps_taken: 2).error?).to be true
      end
    end
  end
end
