# frozen_string_literal: true

require "json"

RSpec.describe Smolagents::AgentLogger do
  describe "#initialize" do
    it "defaults to text format" do
      logger = described_class.new
      expect(logger.format).to eq(:text)
    end

    it "defaults to INFO level" do
      logger = described_class.new
      expect(logger.level).to eq(described_class::INFO)
    end

    it "accepts json format" do
      logger = described_class.new(format: :json)
      expect(logger.format).to eq(:json)
    end

    it "accepts custom log level" do
      logger = described_class.new(level: described_class::DEBUG)
      expect(logger.level).to eq(described_class::DEBUG)
    end
  end

  describe "text format" do
    let(:output) { StringIO.new }
    let(:logger) { described_class.new(output: output, format: :text) }

    it "logs messages with context" do
      logger.info("Task started", agent: "Agents::Code", task_id: 123)
      output.rewind

      expect(output.string).to include("Task started")
      expect(output.string).to include("agent=Agents::Code")
      expect(output.string).to include("task_id=123")
    end

    it "logs messages without context" do
      logger.info("Simple message")
      output.rewind

      expect(output.string).to include("Simple message")
    end
  end

  describe "json format" do
    let(:output) { StringIO.new }
    let(:logger) { described_class.new(output: output, format: :json) }

    it "outputs valid JSON" do
      logger.info("Task started", agent: "Agents::Code")
      output.rewind

      json = JSON.parse(output.string)
      expect(json).to be_a(Hash)
    end

    it "includes timestamp in ISO8601 format" do
      logger.info("Test")
      output.rewind

      json = JSON.parse(output.string)
      expect(json["timestamp"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "includes log level" do
      logger.info("Test")
      output.rewind

      json = JSON.parse(output.string)
      expect(json["level"]).to eq("INFO")
    end

    it "includes message" do
      logger.info("Task completed")
      output.rewind

      json = JSON.parse(output.string)
      expect(json["message"]).to eq("Task completed")
    end

    it "includes context fields" do
      logger.info("Task started", agent: "Agents::Code", task_id: 123)
      output.rewind

      json = JSON.parse(output.string)
      expect(json["agent"]).to eq("Agents::Code")
      expect(json["task_id"]).to eq(123)
    end
  end

  describe "log levels" do
    let(:output) { StringIO.new }

    it "respects log level filtering" do
      logger = described_class.new(output: output, level: described_class::WARN)

      logger.debug("Debug message")
      logger.info("Info message")
      logger.warn("Warn message")
      logger.error("Error message")

      output.rewind
      log_output = output.string

      expect(log_output).not_to include("Debug message")
      expect(log_output).not_to include("Info message")
      expect(log_output).to include("Warn message")
      expect(log_output).to include("Error message")
    end
  end

  describe "step helpers" do
    let(:output) { StringIO.new }
    let(:logger) { described_class.new(output: output, format: :json) }

    describe "#step_start" do
      it "logs step start event" do
        logger.step_start(1, agent: "TestAgent")
        output.rewind

        json = JSON.parse(output.string)
        expect(json["message"]).to include("Step 1 starting")
        expect(json["step"]).to eq(1)
        expect(json["event"]).to eq("step_start")
        expect(json["agent"]).to eq("TestAgent")
      end
    end

    describe "#step_complete" do
      it "logs step complete event with duration" do
        logger.step_complete(1, duration: 1.5)
        output.rewind

        json = JSON.parse(output.string)
        expect(json["message"]).to include("Step 1 complete")
        expect(json["message"]).to include("1.5s")
        expect(json["step"]).to eq(1)
        expect(json["event"]).to eq("step_complete")
        expect(json["duration"]).to eq(1.5)
      end

      it "logs step complete event without duration" do
        logger.step_complete(2)
        output.rewind

        json = JSON.parse(output.string)
        expect(json["message"]).to eq("Step 2 complete")
        expect(json["duration"]).to be_nil
      end
    end

    describe "#step_error" do
      it "logs step error event" do
        error = StandardError.new("Something went wrong")
        logger.step_error(3, error)
        output.rewind

        json = JSON.parse(output.string)
        expect(json["message"]).to include("Step 3 failed")
        expect(json["message"]).to include("Something went wrong")
        expect(json["step"]).to eq(3)
        expect(json["event"]).to eq("step_error")
        expect(json["error_class"]).to eq("StandardError")
      end
    end
  end
end
