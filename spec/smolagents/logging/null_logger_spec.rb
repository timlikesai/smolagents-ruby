require "spec_helper"
require "smolagents/logging"

RSpec.describe Smolagents::Logging::NullLogger do
  subject(:logger) { described_class.instance }

  describe "singleton behavior" do
    it "returns the same instance" do
      instance1 = described_class.instance
      instance2 = described_class.instance
      expect(instance1).to be(instance2)
    end

    it "cannot be instantiated directly" do
      expect { described_class.new }.to raise_error(NoMethodError)
    end
  end

  describe "#level" do
    it "returns :off" do
      expect(logger.level).to eq(:off)
    end
  end

  describe "#level=" do
    it "accepts any value without error" do
      # Ruby setters return the assigned value, not the method's return value
      expect { logger.level = :debug }.not_to raise_error
      expect { logger.level = :info }.not_to raise_error
      expect { logger.level = "anything" }.not_to raise_error
    end

    it "does not change the level" do
      logger.level = :debug
      expect(logger.level).to eq(:off)
    end
  end

  describe "log methods" do
    describe "#debug" do
      it "accepts message and context, returns nil" do
        expect(logger.debug("test message")).to be_nil
        expect(logger.debug("test", key: "value")).to be_nil
        expect(logger.debug).to be_nil
      end
    end

    describe "#info" do
      it "accepts message and context, returns nil" do
        expect(logger.info("test message")).to be_nil
        expect(logger.info("test", key: "value")).to be_nil
        expect(logger.info).to be_nil
      end
    end

    describe "#warn" do
      it "accepts message and context, returns nil" do
        expect(logger.warn("test message")).to be_nil
        expect(logger.warn("test", key: "value")).to be_nil
        expect(logger.warn).to be_nil
      end
    end

    describe "#error" do
      it "accepts message and context, returns nil" do
        expect(logger.error("test message")).to be_nil
        expect(logger.error("test", key: "value")).to be_nil
        expect(logger.error).to be_nil
      end
    end
  end

  describe "step tracking methods" do
    describe "#step_start" do
      it "accepts step number and context, returns nil" do
        expect(logger.step_start(1)).to be_nil
        expect(logger.step_start(1, tool: "search")).to be_nil
      end
    end

    describe "#step_complete" do
      it "accepts step number, duration, and context, returns nil" do
        expect(logger.step_complete(1)).to be_nil
        expect(logger.step_complete(1, duration: 0.5)).to be_nil
        expect(logger.step_complete(1, duration: 0.5, results: 10)).to be_nil
      end
    end

    describe "#step_error" do
      it "accepts step number, error, and context, returns nil" do
        error = RuntimeError.new("test error")
        expect(logger.step_error(1, error)).to be_nil
        expect(logger.step_error(1, error, retry_count: 2)).to be_nil
      end
    end
  end

  describe "#null?" do
    it "returns true" do
      expect(logger.null?).to be true
    end
  end

  describe "AgentLogger interface compatibility" do
    let(:agent_logger) { Smolagents::Telemetry::AgentLogger.new(output: StringIO.new) }

    it "responds to the same methods as AgentLogger" do
      %i[debug info warn error level level= step_start step_complete step_error null?].each do |method|
        expect(logger).to respond_to(method)
        expect(agent_logger).to respond_to(method)
      end
    end

    it "AgentLogger#null? returns false" do
      expect(agent_logger.null?).to be false
    end
  end

  describe "thread safety" do
    it "can be called from multiple threads" do
      threads = Array.new(10) do
        Thread.new do
          100.times do
            logger.info("concurrent call", thread: Thread.current.object_id)
            logger.step_start(1)
            logger.step_complete(1, duration: 0.1)
          end
        end
      end

      expect { threads.each(&:join) }.not_to raise_error
    end
  end
end
