require "spec_helper"

RSpec.describe Smolagents::Telemetry::AgentLogger do
  let(:output) { StringIO.new }
  let(:logger) { described_class.new(output:, level: described_class::DEBUG) }

  describe "log levels" do
    it "defines DEBUG, INFO, WARN, ERROR constants" do
      expect(described_class::DEBUG).to eq(0)
      expect(described_class::INFO).to eq(1)
      expect(described_class::WARN).to eq(2)
      expect(described_class::ERROR).to eq(3)
    end

    it "has LEVEL_NAMES array" do
      expect(described_class::LEVEL_NAMES).to eq(%w[DEBUG INFO WARN ERROR])
    end
  end

  describe "#initialize" do
    it "accepts output, level, and format options" do
      logger = described_class.new(output:, level: described_class::WARN, format: :json)

      expect(logger.level).to eq(described_class::WARN)
      expect(logger.format).to eq(:json)
    end

    it "defaults to INFO level and text format" do
      logger = described_class.new(output:)

      expect(logger.level).to eq(described_class::INFO)
      expect(logger.format).to eq(:text)
    end
  end

  describe "#debug" do
    it "logs debug messages" do
      logger.debug("Debug message")

      expect(output.string).to include("Debug message")
    end

    it "includes context in output" do
      logger.debug("Debug message", key: "value")

      expect(output.string).to include("key=value")
    end
  end

  describe "#info" do
    it "logs info messages" do
      logger.info("Info message")

      expect(output.string).to include("Info message")
    end

    it "includes context in output" do
      logger.info("Info message", task: "research")

      expect(output.string).to include("task=research")
    end
  end

  describe "#warn" do
    it "logs warning messages" do
      logger.warn("Warning message")

      expect(output.string).to include("Warning message")
    end
  end

  describe "#error" do
    it "logs error messages" do
      logger.error("Error message")

      expect(output.string).to include("Error message")
    end
  end

  describe "log level filtering" do
    it "filters messages below the configured level" do
      logger = described_class.new(output:, level: described_class::WARN)

      logger.debug("Debug")
      logger.info("Info")
      logger.warn("Warn")
      logger.error("Error")

      expect(output.string).not_to include("Debug")
      expect(output.string).not_to include("Info")
      expect(output.string).to include("Warn")
      expect(output.string).to include("Error")
    end
  end

  describe "#step_start" do
    it "logs step start with step number" do
      logger.step_start(1)

      expect(output.string).to include("Step 1 starting")
      expect(output.string).to include("step=1")
      expect(output.string).to include("event=step_start")
    end

    it "includes additional context" do
      logger.step_start(2, tool: "search")

      expect(output.string).to include("tool=search")
    end
  end

  describe "#step_complete" do
    it "logs step completion with step number" do
      logger.step_complete(1)

      expect(output.string).to include("Step 1 complete")
      expect(output.string).to include("step=1")
      expect(output.string).to include("event=step_complete")
    end

    it "includes duration when provided" do
      logger.step_complete(1, duration: 0.567)

      expect(output.string).to include("0.57s")
    end

    it "includes additional context" do
      logger.step_complete(1, results: 10)

      expect(output.string).to include("results=10")
    end
  end

  describe "#step_error" do
    it "logs step error with step number and error message" do
      error = StandardError.new("Something went wrong")
      logger.step_error(1, error)

      expect(output.string).to include("Step 1 failed: Something went wrong")
      expect(output.string).to include("step=1")
      expect(output.string).to include("event=step_error")
      expect(output.string).to include("error_class=StandardError")
    end
  end

  describe "#null?" do
    it "returns false" do
      expect(logger.null?).to be(false)
    end
  end

  describe "JSON format" do
    let(:logger) { described_class.new(output:, level: described_class::DEBUG, format: :json) }

    it "outputs JSON-formatted messages" do
      logger.info("Test message", tool: "search")

      parsed = JSON.parse(output.string)

      expect(parsed["level"]).to eq("INFO")
      expect(parsed["message"]).to eq("Test message")
      expect(parsed["tool"]).to eq("search")
      expect(parsed["timestamp"]).to match(/\d{4}-\d{2}-\d{2}T/)
    end

    it "formats step events as JSON" do
      logger.step_start(1, tool: "web")

      parsed = JSON.parse(output.string)

      expect(parsed["message"]).to eq("Step 1 starting")
      expect(parsed["step"]).to eq(1)
      expect(parsed["event"]).to eq("step_start")
    end
  end

  describe "level accessor" do
    it "allows changing log level after initialization" do
      logger = described_class.new(output:, level: described_class::DEBUG)

      expect(logger.level).to eq(described_class::DEBUG)

      logger.level = described_class::ERROR

      expect(logger.level).to eq(described_class::ERROR)
    end
  end
end
