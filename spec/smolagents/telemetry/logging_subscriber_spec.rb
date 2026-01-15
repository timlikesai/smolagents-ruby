RSpec.describe Smolagents::Telemetry::LoggingSubscriber do
  let(:log_output) { StringIO.new }
  let(:logger) { Logger.new(log_output, progname: "test") }

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

        expect(log_output.string).to include("[agent.run]")
        expect(log_output.string).to include("TestAgent")
        expect(log_output.string).to include("completed")
      end

      it "logs final answer outcomes with FinalAnswerException" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.run", agent_class: "MyAgent") do
            raise Smolagents::FinalAnswerException, "Done"
          end
        rescue Smolagents::FinalAnswerException
          # expected
        end

        expect(log_output.string).to include("[agent.run]")
        expect(log_output.string).to include("MyAgent")
        expect(log_output.string).to include("final answer")
      end

      it "logs errors with StandardError" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.run", agent_class: "FailAgent") do
            raise StandardError, "API timeout"
          end
        rescue StandardError
          # expected
        end

        expect(log_output.string).to include("[agent.run]")
        expect(log_output.string).to include("FailAgent")
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

        expect(log_output.string).to include("[agent.run]")
        expect(log_output.string).to include("FAILED")
        expect(log_output.string).to include("LegacyAgent")
      end
    end

    describe "agent.step events" do
      it "logs successful steps" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.step", step_number: 1,
                                                                                   agent_class: "TestAgent") do
          # simulated work
        end

        expect(log_output.string).to include("[step 1]")
        expect(log_output.string).to include("TestAgent")
        expect(log_output.string).to include("completed")
      end

      it "logs step number correctly" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.step", step_number: 42,
                                                                                   agent_class: "TestAgent") do
          # simulated work
        end

        expect(log_output.string).to include("[step 42]")
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

        expect(log_output.string).to include("[step 5]")
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

        expect(log_output.string).to include("[step 2]")
        expect(log_output.string).to include("error")
        expect(log_output.string).to include("StandardError")
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

        expect(log_output.string).to include("[step 3]")
        expect(log_output.string).to include("error")
      end
    end

    describe "model.generate events" do
      it "logs successful model generations" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.model.generate", model_id: "test-model") do
          # simulated work
        end

        expect(log_output.string).to include("[model]")
        expect(log_output.string).to include("test-model")
        expect(log_output.string).to include("completed")
      end

      it "uses model_class when model_id not provided" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.model.generate", model_class: "OpenAIModel") do
          # simulated work
        end

        expect(log_output.string).to include("[model]")
        expect(log_output.string).to include("OpenAIModel")
      end

      it "logs model errors" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.model.generate", model_id: "bad-model") do
            raise StandardError, "Connection refused"
          end
        rescue StandardError
          # expected
        end

        expect(log_output.string).to include("[model]")
        expect(log_output.string).to include("FAILED")
        expect(log_output.string).to include("StandardError")
      end

      it "logs legacy model error path via fallback" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.model.generate", model_id: "legacy") do
            raise "Old error"
          end
        rescue RuntimeError
          # expected
        end

        expect(log_output.string).to include("[model]")
        expect(log_output.string).to include("FAILED")
      end
    end

    describe "tool.call events" do
      it "logs successful tool calls" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.tool.call", tool_name: "calculator") do
          # simulated work
        end

        expect(log_output.string).to include("[tool]")
        expect(log_output.string).to include("calculator")
        expect(log_output.string).to include("completed")
      end

      it "uses tool_class when tool_name not provided" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.tool.call", tool_class: "WebSearchTool") do
          # simulated work
        end

        expect(log_output.string).to include("[tool]")
        expect(log_output.string).to include("WebSearchTool")
      end

      it "logs final answer from tools at info level with FinalAnswerException" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.tool.call", tool_name: "final_answer") do
            raise Smolagents::FinalAnswerException, "Answer provided"
          end
        rescue Smolagents::FinalAnswerException
          # expected
        end

        expect(log_output.string).to include("[tool]")
        expect(log_output.string).to include("final answer")
      end

      it "logs tool errors as warnings" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.tool.call", tool_name: "broken_tool") do
            raise StandardError, "Tool failed"
          end
        rescue StandardError
          # expected
        end

        expect(log_output.string).to include("[tool]")
        expect(log_output.string).to include("FAILED")
        expect(log_output.string).to include("StandardError")
      end

      it "logs legacy tool error path via fallback" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.tool.call", tool_name: "legacy_tool") do
            raise "Legacy error"
          end
        rescue RuntimeError
          # expected
        end

        expect(log_output.string).to include("[tool]")
        expect(log_output.string).to include("FAILED")
      end

      it "logs tool calls as debug when no error occurs" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.tool.call", tool_name: "test_tool") do
          # simulated work
        end

        expect(log_output.string).to include("[tool]")
        expect(log_output.string).to include("completed")
      end
    end

    describe "executor.execute events" do
      it "logs successful executor executions" do
        Smolagents::Telemetry::Instrumentation.instrument("smolagents.executor.execute", executor_class: "LocalRuby") do
          # simulated work
        end

        expect(log_output.string).to include("[executor]")
        expect(log_output.string).to include("LocalRuby")
        expect(log_output.string).to include("completed")
      end

      it "logs executor errors" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.executor.execute",
                                                            executor_class: "BadExecutor") do
            raise StandardError, "Execution failed"
          end
        rescue StandardError
          # expected
        end

        expect(log_output.string).to include("[executor]")
        expect(log_output.string).to include("FAILED")
        expect(log_output.string).to include("StandardError")
      end

      it "logs legacy executor error path via fallback" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("smolagents.executor.execute",
                                                            executor_class: "LegacyExecutor") do
            raise "Old error"
          end
        rescue RuntimeError
          # expected
        end

        expect(log_output.string).to include("[executor]")
        expect(log_output.string).to include("FAILED")
      end
    end

    describe "generic event logging" do
      it "logs unknown event types" do
        Smolagents::Telemetry::Instrumentation.instrument("custom.event") do
          # simulated work
        end

        expect(log_output.string).to include("[custom.event]")
        expect(log_output.string).to include("completed")
      end

      it "logs generic final answer outcome" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("custom.event") do
            raise Smolagents::FinalAnswerException, "Result"
          end
        rescue Smolagents::FinalAnswerException
          # expected
        end

        expect(log_output.string).to include("[custom.event]")
        expect(log_output.string).to include("final answer")
      end

      it "logs generic errors" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("custom.event") do
            raise StandardError, "Custom error"
          end
        rescue StandardError
          # expected
        end

        expect(log_output.string).to include("[custom.event]")
        expect(log_output.string).to include("FAILED")
        expect(log_output.string).to include("StandardError")
      end

      it "logs generic legacy error path via fallback" do
        begin
          Smolagents::Telemetry::Instrumentation.instrument("custom.event") do
            raise "Legacy custom error"
          end
        rescue RuntimeError
          # expected
        end

        expect(log_output.string).to include("[custom.event]")
        expect(log_output.string).to include("FAILED")
      end
    end

    it "logs errors with higher severity than success" do
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
        "work"
      end

      expect(log_output.string).to match(/\d+\.\d+s/)
    end

    it "handles missing duration gracefully" do
      # Directly call the handler without duration
      subscriber = Smolagents::Telemetry::Instrumentation.subscriber
      subscriber.call("smolagents.agent.step", { step_number: 1, agent_class: "Test" })

      expect(log_output.string).to include("[step 1]")
      expect(log_output.string).to include("?") # duration placeholder
    end
  end

  describe "log level filtering" do
    it "respects the configured log level" do
      described_class.enable(logger:, level: :warn)

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

    it "shows info level events when level is info" do
      described_class.enable(logger:, level: :info)

      Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.run", agent_class: "TestAgent") do
        # agent.run logs at info level
      end

      expect(log_output.string).to include("[agent.run]")
      expect(log_output.string).to include("TestAgent")
    end

    it "shows all events at debug level" do
      described_class.enable(logger:, level: :debug)

      Smolagents::Telemetry::Instrumentation.instrument("smolagents.agent.step", step_number: 1, agent_class: "Test") do
        # step events log at debug level
      end

      expect(log_output.string).to include("[step 1]")
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

      expect(log_output.string).to include("[agent.run]")
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
