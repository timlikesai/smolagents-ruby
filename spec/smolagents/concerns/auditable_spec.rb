RSpec.describe Smolagents::Concerns::Auditable do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Auditable
    end
  end

  let(:instance) { test_class.new }
  let(:mock_logger) do
    # Using double() since StructuredLogger is a generic interface, not a specific class
    logger = double("StructuredLogger")
    allow(logger).to receive(:respond_to?).with(:info).and_return(true)
    allow(logger).to receive(:method).with(:info).and_return(double(arity: -1))
    logger
  end

  before do
    Smolagents.configuration.audit_logger = mock_logger
  end

  after do
    Smolagents.reset_configuration!
  end

  describe "#with_audit_log" do
    it "returns result on successful operation" do
      allow(mock_logger).to receive(:info)

      result = instance.with_audit_log(service: "test_service", operation: "test_operation") do
        "success"
      end

      expect(result).to eq("success")
    end

    it "logs request with success status" do
      expect(mock_logger).to receive(:info).with("HTTP Request", hash_including(
                                                                   service: "test_service",
                                                                   operation: "test_operation",
                                                                   status: :success
                                                                 ))

      instance.with_audit_log(service: "test_service", operation: "test_operation") do
        "success"
      end
    end

    it "includes request_id in log" do
      expect(mock_logger).to receive(:info) do |msg, **attrs|
        expect(msg).to eq("HTTP Request")
        expect(attrs[:request_id]).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      end

      instance.with_audit_log(service: "test_service", operation: "test_operation") do
        "success"
      end
    end

    it "includes duration_ms in log" do
      expect(mock_logger).to receive(:info) do |msg, **attrs|
        expect(msg).to eq("HTTP Request")
        expect(attrs[:duration_ms]).to be_a(Float)
      end

      instance.with_audit_log(service: "test_service", operation: "test_operation") do
        "success"
      end
    end

    it "logs with error status on exception" do
      expect(mock_logger).to receive(:info).with("HTTP Request", hash_including(
                                                                   service: "test_service",
                                                                   operation: "test_operation",
                                                                   status: :error,
                                                                   error: "StandardError"
                                                                 ))

      expect do
        instance.with_audit_log(service: "test_service", operation: "test_operation") do
          raise StandardError, "test error"
        end
      end.to raise_error(StandardError, "test error")
    end

    it "re-raises the exception after logging" do
      allow(mock_logger).to receive(:info)

      expect do
        instance.with_audit_log(service: "test_service", operation: "test_operation") do
          raise ArgumentError, "custom error"
        end
      end.to raise_error(ArgumentError, "custom error")
    end

    it "logs duration even when operation fails" do
      expect(mock_logger).to receive(:info) do |msg, **attrs|
        expect(msg).to eq("HTTP Request")
        expect(attrs[:duration_ms]).to be_a(Float)
      end

      expect do
        instance.with_audit_log(service: "test_service", operation: "test_operation") do
          raise StandardError, "error"
        end
      end.to raise_error(StandardError)
    end

    it "does not log when audit_logger is nil" do
      Smolagents.configuration.audit_logger = nil

      result = instance.with_audit_log(service: "test_service", operation: "test_operation") do
        "success"
      end

      expect(result).to eq("success")
    end

    it "generates unique request_ids for multiple calls" do
      request_ids = []

      allow(mock_logger).to receive(:info) do |_msg, **attrs|
        request_ids << attrs[:request_id]
      end

      3.times do
        instance.with_audit_log(service: "test_service", operation: "test_operation") do
          "success"
        end
      end

      expect(request_ids.uniq.size).to eq(3)
    end

    it "captures duration in attributes" do
      expect(mock_logger).to receive(:info) do |_msg, **attrs|
        expect(attrs[:duration_ms]).to be_a(Float)
      end

      instance.with_audit_log(service: "test_service", operation: "test_operation") do
        "success"
      end
    end

    context "with standard Ruby Logger" do
      let(:log_output) { StringIO.new }
      let(:ruby_logger) { Logger.new(log_output) }

      before do
        Smolagents.configuration.audit_logger = ruby_logger
      end

      it "formats log message as string for standard logger" do
        instance.with_audit_log(service: "test_service", operation: "test_operation") do
          "success"
        end

        log_output.rewind
        log_content = log_output.read

        expect(log_content).to match(/HTTP Request/)
        expect(log_content).to match(/request_id=/)
        expect(log_content).to match(/service=test_service/)
        expect(log_content).to match(/operation=test_operation/)
        expect(log_content).to match(/status=success/)
      end
    end
  end

  describe "integration with models" do
    it "works with a model-like class" do
      api_client = Class.new do
        include Smolagents::Concerns::Auditable

        def call_api
          with_audit_log(service: "openai", operation: "chat_completion") do
            { response: "Hello, world!" }
          end
        end
      end

      expect(mock_logger).to receive(:info).with("HTTP Request", hash_including(
                                                                   service: "openai",
                                                                   operation: "chat_completion",
                                                                   status: :success
                                                                 ))

      client = api_client.new
      result = client.call_api

      expect(result[:response]).to eq("Hello, world!")
    end

    it "handles errors in model-like class" do
      api_client = Class.new do
        include Smolagents::Concerns::Auditable

        def call_api
          with_audit_log(service: "anthropic", operation: "messages") do
            raise Faraday::TimeoutError, "Request timeout"
          end
        end
      end

      expect(mock_logger).to receive(:info).with("HTTP Request", hash_including(
                                                                   service: "anthropic",
                                                                   operation: "messages",
                                                                   status: :error,
                                                                   error: "Faraday::TimeoutError"
                                                                 ))

      client = api_client.new
      expect { client.call_api }.to raise_error(Faraday::TimeoutError)
    end
  end
end
