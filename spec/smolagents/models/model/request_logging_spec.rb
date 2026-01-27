RSpec.describe Smolagents::Models::Model::RequestLogging do
  let(:model_class) do
    Class.new(Smolagents::Models::Model) do
      include Smolagents::Models::Model::RequestLogging

      def initialize
        super(model_id: "test-model")
        initialize_request_logging
      end

      def model_id = "test-model"

      def generate(messages, **)
        with_generate_events(messages, **) do
          Smolagents::Types::ChatMessage.assistant("Hello!")
        end
      end
    end
  end

  let(:model) { model_class.new }

  describe "#initialize_request_logging" do
    it "sets up empty request_logs array" do
      expect(model.request_logs).to eq([])
    end

    it "enables request_logging?" do
      expect(model.request_logging?).to be true
    end
  end

  describe "#request_logging?" do
    it "returns true when logging is initialized" do
      expect(model.request_logging?).to be true
    end

    it "returns false when logging is not initialized" do
      # Create a model that includes the module but doesn't call initialize_request_logging
      uninit_class = Class.new(Smolagents::Models::Model) do
        include Smolagents::Models::Model::RequestLogging

        def initialize
          super(model_id: "test")
          # Don't call initialize_request_logging
        end
      end

      expect(uninit_class.new.request_logging?).to be_falsey
    end
  end

  describe "request tracking" do
    let(:messages) { [Smolagents::Types::ChatMessage.user("Hello")] }

    it "records requests when generate is called" do
      model.generate(messages)

      expect(model.request_logs.size).to eq(1)
    end

    it "records request details" do
      model.generate(messages)

      log = model.request_logs.first
      expect(log.model_id).to eq("test-model")
      expect(log.message_count).to eq(1)
    end

    it "records multiple requests" do
      model.generate(messages)
      model.generate(messages)
      model.generate(messages)

      expect(model.request_logs.size).to eq(3)
    end
  end

  describe "#last_requests" do
    let(:messages) { [Smolagents::Types::ChatMessage.user("Hello")] }

    before do
      3.times { model.generate(messages) }
    end

    it "returns all requests by default" do
      expect(model.last_requests.size).to eq(3)
    end

    it "returns last N requests when count specified" do
      expect(model.last_requests(2).size).to eq(2)
    end

    it "returns a copy of the array" do
      result = model.last_requests
      expect(result).not_to be(model.request_logs)
    end
  end

  describe "#clear_request_logs" do
    let(:messages) { [Smolagents::Types::ChatMessage.user("Hello")] }

    it "clears all logs" do
      model.generate(messages)
      model.generate(messages)

      model.clear_request_logs

      expect(model.request_logs).to be_empty
    end

    it "returns self for chaining" do
      expect(model.clear_request_logs).to eq(model)
    end
  end

  describe "#total_tokens_used" do
    it "returns 0 when no requests" do
      expect(model.total_tokens_used).to eq(0)
    end
  end

  describe "#total_duration_ms" do
    it "returns 0 when no requests" do
      expect(model.total_duration_ms).to eq(0)
    end
  end

  describe "#requests_since" do
    let(:messages) { [Smolagents::Types::ChatMessage.user("Hello")] }

    it "filters logs by timestamp" do
      cutoff = Time.now
      model.generate(messages)

      result = model.requests_since(cutoff)
      expect(result.size).to eq(1)
    end
  end
end
