RSpec.describe Smolagents::Telemetry::LoggingSubscriber do
  let(:log_output) { StringIO.new }
  let(:logger) { Logger.new(log_output, progname: "test") }

  after do
    described_class.disable
  end

  describe ".enable" do
    it "sets up the subscriber" do
      expect(described_class.enable(logger: logger)).to be true
      expect(described_class.enabled?).to be true
    end

    it "configures the instrumentation subscriber" do
      described_class.enable(logger: logger)
      expect(Smolagents::Telemetry::Instrumentation.subscriber).not_to be_nil
    end
  end

  describe ".disable" do
    it "clears the subscriber" do
      described_class.enable(logger: logger)
      described_class.disable
      expect(described_class.enabled?).to be false
      expect(Smolagents::Telemetry::Instrumentation.subscriber).to be_nil
    end
  end

  describe "event logging" do
    before do
      described_class.enable(logger: logger, level: :debug)
    end

    it "logs agent.run events" do
      Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.run", agent_class: "TestAgent") do
        # simulated work
      end

      expect(log_output.string).to include("[agent.run]")
      expect(log_output.string).to include("TestAgent")
      expect(log_output.string).to include("completed")
    end

    it "logs agent.step events" do
      Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.step", step_number: 1, agent_class: "TestAgent") do
        # simulated work
      end

      expect(log_output.string).to include("[step 1]")
      expect(log_output.string).to include("TestAgent")
    end

    it "logs model.generate events" do
      Smolagents::Telemetry::Instrumentation.instrument("smolagents.model.generate", model_id: "test-model") do
        # simulated work
      end

      expect(log_output.string).to include("[model]")
      expect(log_output.string).to include("test-model")
    end

    it "logs tool.call events" do
      Smolagents::Telemetry::Instrumentation.instrument("smolagents.tool.call", tool_name: "calculator") do
        # simulated work
      end

      expect(log_output.string).to include("[tool]")
      expect(log_output.string).to include("calculator")
    end

    it "logs executor.execute events" do
      Smolagents::Telemetry::Instrumentation.instrument("smolagents.executor.execute", executor_class: "LocalRuby") do
        # simulated work
      end

      expect(log_output.string).to include("[executor]")
      expect(log_output.string).to include("LocalRuby")
    end

    it "logs errors with higher severity" do
      begin
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.model.generate", model_id: "test-model") do
          raise StandardError, "API error"
        end
      rescue StandardError
        # expected
      end

      expect(log_output.string).to include("FAILED")
      expect(log_output.string).to include("StandardError")
    end

    it "includes duration in log messages" do
      Smolagents::Telemetry::Instrumentation.instrument("smolagents.tool.call", tool_name: "test") do
        sleep(0.01)
      end

      expect(log_output.string).to match(/\d+\.\d+s/)
    end
  end

  describe "log level filtering" do
    it "respects the configured log level" do
      described_class.enable(logger: logger, level: :warn)

      # Debug events should not appear
      Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.step", step_number: 1, agent_class: "Test") do
        # step events log at debug level
      end

      expect(log_output.string).not_to include("[step 1]")

      # Error events should appear
      begin
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.model.generate", model_id: "test") do
          raise "error"
        end
      rescue StandardError
        # expected
      end

      expect(log_output.string).to include("FAILED")
    end
  end
end
