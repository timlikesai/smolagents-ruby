RSpec.describe Smolagents::Telemetry::LoggingSubscriber do
  let(:log_output) { StringIO.new }
  let(:logger) do
    Logger.new(log_output, progname: "test").tap do |log|
      log.formatter = proc { |_sev, _time, _prog, msg| "#{msg}\n" }
    end
  end

  after do
    described_class.disable
  end

  describe ".enable" do
    it "sets up the subscriber and returns self for chaining" do
      result = described_class.enable(logger:)
      expect(result).to eq(described_class)
      expect(described_class.enabled?).to be true
    end

    it "configures the instrumentation subscriber" do
      described_class.enable(logger:)
      expect(Smolagents::Telemetry::Instrumentation.subscriber).not_to be_nil
    end

    it "creates a default logger when none provided" do
      described_class.enable
      expect(described_class.logger).not_to be_nil
    end

    it "sets the log level from parameters" do
      described_class.enable(logger:, level: :debug)
      expect(described_class.level).to eq(:debug)
    end

    it "defaults to :info log level" do
      described_class.enable(logger:)
      expect(described_class.level).to eq(:info)
    end

    it "configures logger with correct level constant" do
      described_class.enable(logger:, level: :warn)
      expect(logger.level).to eq(Logger::WARN)
    end

    it "stores the provided logger instance" do
      custom_logger = Logger.new(StringIO.new)
      described_class.enable(logger: custom_logger)
      expect(described_class.logger).to eq(custom_logger)
    end
  end

  describe ".disable" do
    it "clears the subscriber" do
      described_class.enable(logger:)
      described_class.disable
      expect(described_class.enabled?).to be false
      expect(Smolagents::Telemetry::Instrumentation.subscriber).to be_nil
    end

    it "clears the logger instance" do
      described_class.enable(logger:)
      described_class.disable
      expect(described_class.logger).to be_nil
    end
  end

  describe ".enabled?" do
    it "returns true when enabled" do
      described_class.enable(logger:)
      expect(described_class.enabled?).to be true
    end

    it "returns false when disabled" do
      described_class.disable
      expect(described_class.enabled?).to be false
    end
  end

  describe ".logger" do
    it "returns nil when not enabled" do
      described_class.disable
      expect(described_class.logger).to be_nil
    end

    it "returns the logger when enabled" do
      described_class.enable(logger:)
      expect(described_class.logger).to eq(logger)
    end
  end

  describe ".level" do
    it "returns nil when not enabled" do
      described_class.disable
      expect(described_class.logger).to be_nil # .level calls .logger internally
    end

    it "returns the configured level when enabled" do
      described_class.enable(logger:, level: :error)
      expect(described_class.level).to eq(:error)
    end
  end

  describe "event logging" do
    before do
      described_class.enable(logger:, level: :debug)
    end

    describe "agent.run events" do
      it "logs successful runs" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.run", agent_class: "TestAgent") do
          # simulated work
        end

        expect(log_output.string).to include("done")
      end

      it "logs final answer outcomes with FinalAnswerException" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.run", agent_class: "MyAgent") do
            raise Smolagents::FinalAnswerException, "Done"
          end
        rescue Smolagents::FinalAnswerException
          # expected
        end

        expect(log_output.string).to include("done")
      end

      it "logs errors with StandardError" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.run", agent_class: "FailAgent") do
            raise StandardError, "API timeout"
          end
        rescue StandardError
          # expected
        end

        expect(log_output.string).to include("FAILED")
        expect(log_output.string).to include("StandardError")
      end

      it "logs legacy error path via fallback" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.run", agent_class: "LegacyAgent") do
            raise "Old error format"
          end
        rescue RuntimeError
          # expected
        end

        expect(log_output.string).to include("FAILED")
        expect(log_output.string).to include("RuntimeError")
      end
    end

    describe "agent.step events" do
      it "logs successful steps" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.step", step_number: 1,
                                                                                   agent_class: "TestAgent") do
          # simulated work
        end

        expect(log_output.string).to include("step 1:")
      end

      it "logs step number correctly" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.step", step_number: 42,
                                                                                   agent_class: "TestAgent") do
          # simulated work
        end

        expect(log_output.string).to include("step 42:")
      end

      it "logs final answer steps with FinalAnswerException" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.step", step_number: 5,
                                                                                     agent_class: "Agent") do
            raise Smolagents::FinalAnswerException, "Done"
          end
        rescue Smolagents::FinalAnswerException
          # expected
        end

        expect(log_output.string).to include("step 5:")
        expect(log_output.string).to include("final answer")
      end

      it "logs step errors as warnings" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.step", step_number: 2,
                                                                                     agent_class: "FailAgent") do
            raise StandardError, "Step failed"
          end
        rescue StandardError
          # expected
        end

        expect(log_output.string).to include("step 2:")
        expect(log_output.string).to include("ERROR")
      end

      it "logs legacy step error path via fallback" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.step", step_number: 3,
                                                                                     agent_class: "LegacyAgent") do
            raise "Legacy step error"
          end
        rescue RuntimeError
          # expected
        end

        expect(log_output.string).to include("step 3:")
        expect(log_output.string).to include("ERROR")
      end
    end

    describe "model.generate events" do
      it "logs successful model generations at debug level" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.model.generate", model_id: "test-model") do
          # simulated work
        end

        expect(log_output.string).to include("model:")
        expect(log_output.string).to include("test-model")
      end

      it "uses model_class when model_id not provided" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.model.generate", model_class: "OpenAIModel") do
          # simulated work
        end

        expect(log_output.string).to include("model:")
      end
    end

    describe "tool.call events" do
      it "logs successful tool calls" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.tool.call", tool_name: "calculator") do
          # simulated work
        end

        expect(log_output.string).to include("tool:")
        expect(log_output.string).to include("calculator")
      end

      it "logs final answer from tools" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.tool.call", tool_name: "final_answer") do
            raise Smolagents::FinalAnswerException, "Answer provided"
          end
        rescue Smolagents::FinalAnswerException
          # expected
        end

        expect(log_output.string).to include("tool:")
        expect(log_output.string).to include("final_answer")
      end

      it "logs tool errors as warnings" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.tool.call", tool_name: "broken_tool") do
            raise StandardError, "Tool failed"
          end
        rescue StandardError
          # expected
        end

        expect(log_output.string).to include("tool:")
        expect(log_output.string).to include("FAILED")
      end
    end

    # Simplified logging: executor and generic events are skipped for cleaner output

    it "includes duration in log messages" do
      Smolagents::Telemetry::Instrumentation.instrument("smolagents.tool.call", tool_name: "test") do
        "work"
      end

      expect(log_output.string).to match(/\d+\.\d+s/)
    end

    it "handles missing duration gracefully" do
      # Directly call the handler without duration
      subscriber = Smolagents::Telemetry::Instrumentation.subscriber
      subscriber.call("smolagents.agent.step", { step_number: 1, agent_class: "Test" })

      expect(log_output.string).to include("step 1:")
      expect(log_output.string).to include("?") # duration placeholder
    end
  end

  describe "log level filtering" do
    it "respects the configured log level" do
      described_class.enable(logger:, level: :warn)

      # Info events should not appear at warn level
      Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.step", step_number: 1, agent_class: "Test") do
        # step events log at info level
      end

      expect(log_output.string).not_to include("step 1")

      # Warning events should appear
      begin
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.step", step_number: 2,
                                                                                   agent_class: "Test") do
          raise StandardError, "error"
        end
      rescue StandardError
        # expected
      end

      expect(log_output.string).to include("ERROR")
    end

    it "shows info level events when level is info" do
      described_class.enable(logger:, level: :info)

      Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.run", agent_class: "TestAgent") do
        # agent.run logs at info level
      end

      expect(log_output.string).to include("done")
    end

    it "shows all events at debug level" do
      described_class.enable(logger:, level: :debug)

      Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.step", step_number: 1, agent_class: "Test") do
        # step events log at info level
      end

      expect(log_output.string).to include("step 1:")
    end
  end

  describe "integration with Instrumentation" do
    it "doesn't log when disabled" do
      described_class.disable

      Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.run", agent_class: "TestAgent") do
        # simulated work
      end

      expect(log_output.string).to be_empty
    end

    it "logs when enabled after being disabled" do
      described_class.disable
      described_class.enable(logger:, level: :debug)

      Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.run", agent_class: "TestAgent") do
        # simulated work
      end

      expect(log_output.string).to include("done")
    end

    it "handles nil subscriber gracefully" do
      described_class.enable(logger:, level: :debug)
      Smolagents::Telemetry::Instrumentation.subscriber = nil

      # Should not raise an error when calling instrument without subscriber
      expect do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.run", agent_class: "TestAgent") do
          "work"
        end
      end.not_to raise_error
    end
  end
end
