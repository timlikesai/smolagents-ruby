RSpec.describe Smolagents::Concerns::Resilience::FailureCapture do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Consumer
      include Smolagents::Concerns::Resilience::FailureCapture

      def initialize(max_failures: 5)
        initialize_failure_capture(max_failures:)
      end
    end
  end

  let(:capturer) { test_class.new }

  def create_error_event(message: "fail", error_class: "RuntimeError", context: {})
    Smolagents::Events::ErrorOccurred.create(
      error: RuntimeError.new(message),
      context:,
      recoverable: false
    )
  end

  describe "#last_failures" do
    it "starts empty" do
      expect(capturer.last_failures).to be_empty
    end

    it "captures failures from error events" do
      capturer.consume(create_error_event)

      expect(capturer.last_failures.size).to eq(1)
    end

    it "returns a defensive copy" do
      capturer.consume(create_error_event)

      capturer.last_failures.clear
      expect(capturer.last_failures.size).to eq(1)
    end

    it "respects max_failures circular buffer" do
      small = test_class.new(max_failures: 2)
      3.times { |i| small.consume(create_error_event(message: "error #{i}")) }

      expect(small.last_failures.size).to eq(2)
      expect(small.last_failures.first.error_message).to eq("error 1")
      expect(small.last_failures.last.error_message).to eq("error 2")
    end
  end

  describe "#last_failure" do
    it "returns nil when no failures" do
      expect(capturer.last_failure).to be_nil
    end

    it "returns the most recent failure" do
      capturer.consume(create_error_event(message: "first"))
      capturer.consume(create_error_event(message: "second"))

      expect(capturer.last_failure.error_message).to eq("second")
    end
  end

  describe "#failure_count" do
    it "returns zero initially" do
      expect(capturer.failure_count).to eq(0)
    end

    it "tracks failure count" do
      2.times { capturer.consume(create_error_event) }

      expect(capturer.failure_count).to eq(2)
    end
  end

  describe "#clear_failures!" do
    it "clears all captured failures" do
      capturer.consume(create_error_event)
      capturer.clear_failures!

      expect(capturer.last_failures).to be_empty
    end

    it "returns self for chaining" do
      expect(capturer.clear_failures!).to eq(capturer)
    end
  end

  describe "snapshot content" do
    it "captures error_class from the event" do
      capturer.consume(create_error_event)

      expect(capturer.last_failure.error_class).to eq("RuntimeError")
    end

    it "captures error_message from the event" do
      capturer.consume(create_error_event(message: "something broke"))

      expect(capturer.last_failure.error_message).to eq("something broke")
    end

    it "captures timestamp" do
      capturer.consume(create_error_event)

      expect(capturer.last_failure.timestamp).to be_a(Time)
    end
  end

  describe "context extraction" do
    it "extracts model_id from context" do
      event = create_error_event(context: { model_id: "gemma-3n" })
      capturer.consume(event)

      expect(capturer.last_failure.model_id).to eq("gemma-3n")
    end

    it "extracts step_number from context" do
      event = create_error_event(context: { step_number: 3 })
      capturer.consume(event)

      expect(capturer.last_failure.step_number).to eq(3)
    end

    it "extracts request_summary from context" do
      event = create_error_event(context: { request_summary: "POST /v1/chat" })
      capturer.consume(event)

      expect(capturer.last_failure.request_summary).to eq("POST /v1/chat")
    end

    it "extracts response_summary from context" do
      event = create_error_event(context: { response_summary: "500 Error" })
      capturer.consume(event)

      expect(capturer.last_failure.response_summary).to eq("500 Error")
    end

    it "handles missing context gracefully" do
      capturer.consume(create_error_event(context: {}))

      snapshot = capturer.last_failure
      expect(snapshot.model_id).to be_nil
      expect(snapshot.step_number).to be_nil
    end
  end

  describe "string truncation" do
    it "truncates long error messages to 500 characters" do
      long_message = "x" * 600
      capturer.consume(create_error_event(message: long_message))

      expect(capturer.last_failure.error_message.length).to eq(500)
      expect(capturer.last_failure.error_message).to end_with("...")
    end

    it "preserves short strings unchanged" do
      capturer.consume(create_error_event(message: "short"))

      expect(capturer.last_failure.error_message).to eq("short")
    end
  end
end
