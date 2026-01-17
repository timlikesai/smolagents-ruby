require "spec_helper"
require "smolagents/logging"

RSpec.describe Smolagents::Logging do
  describe "module structure" do
    it "provides NullLogger" do
      expect(described_class::NullLogger).to be_a(Class)
    end

    it "provides RawOutputLogger" do
      expect(described_class::RawOutputLogger).to be_a(Class)
    end
  end

  describe Smolagents::Logging::NullLogger do
    subject(:logger) { described_class.instance }

    describe "singleton pattern" do
      it "is a singleton" do
        expect(described_class.included_modules).to include(Singleton)
      end

      it "returns same instance" do
        expect(described_class.instance).to be(described_class.instance)
      end
    end

    describe "#level" do
      it "returns :off" do
        expect(logger.level).to eq(:off)
      end
    end

    describe "#level=" do
      it "ignores the value and level remains :off" do
        logger.level = :debug
        expect(logger.level).to eq(:off)
      end

      it "accepts any value without error" do
        expect { logger.level = :info }.not_to raise_error
        expect { logger.level = :warn }.not_to raise_error
        expect { logger.level = nil }.not_to raise_error
      end
    end

    describe "#null?" do
      it "returns true" do
        expect(logger.null?).to be true
      end
    end

    describe "log methods" do
      describe "#debug" do
        it "returns nil" do
          expect(logger.debug("test message")).to be_nil
        end

        it "accepts keyword arguments" do
          expect(logger.debug("message", key: "value", other: 123)).to be_nil
        end

        it "works without message" do
          expect(logger.debug).to be_nil
        end
      end

      describe "#info" do
        it "returns nil" do
          expect(logger.info("test message")).to be_nil
        end

        it "accepts keyword arguments" do
          expect(logger.info("message", context: { foo: "bar" })).to be_nil
        end

        it "works without message" do
          expect(logger.info).to be_nil
        end
      end

      describe "#warn" do
        it "returns nil" do
          expect(logger.warn("warning message")).to be_nil
        end

        it "accepts keyword arguments" do
          expect(logger.warn("message", severity: :high)).to be_nil
        end

        it "works without message" do
          expect(logger.warn).to be_nil
        end
      end

      describe "#error" do
        it "returns nil" do
          expect(logger.error("error message")).to be_nil
        end

        it "accepts keyword arguments" do
          expect(logger.error("message", exception: StandardError.new)).to be_nil
        end

        it "works without message" do
          expect(logger.error).to be_nil
        end
      end
    end

    describe "step tracking methods" do
      describe "#step_start" do
        it "returns nil" do
          expect(logger.step_start(1)).to be_nil
        end

        it "accepts keyword arguments" do
          expect(logger.step_start(1, task: "compute", model: "gpt-4")).to be_nil
        end
      end

      describe "#step_complete" do
        it "returns nil" do
          expect(logger.step_complete(1)).to be_nil
        end

        it "accepts duration keyword" do
          expect(logger.step_complete(1, duration: 1.5)).to be_nil
        end

        it "accepts additional keyword arguments" do
          expect(logger.step_complete(1, duration: 0.5, result: "success")).to be_nil
        end
      end

      describe "#step_error" do
        it "returns nil" do
          expect(logger.step_error(1, StandardError.new("boom"))).to be_nil
        end

        it "accepts keyword arguments" do
          expect(logger.step_error(1, RuntimeError.new, context: "processing")).to be_nil
        end
      end
    end

    describe "use as default logger" do
      it "can be used as fallback without nil checks" do
        logger_or_null = described_class.instance

        # All these should work without raising
        expect { logger_or_null.info("message") }.not_to raise_error
        expect { logger_or_null.debug("debug") }.not_to raise_error
        expect { logger_or_null.warn("warning") }.not_to raise_error
        expect { logger_or_null.error("error") }.not_to raise_error
        expect { logger_or_null.step_start(1) }.not_to raise_error
        expect { logger_or_null.step_complete(1, duration: 0.1) }.not_to raise_error
        expect { logger_or_null.step_error(1, StandardError.new) }.not_to raise_error
      end
    end
  end

  describe "logger interface compatibility" do
    let(:null_logger) { Smolagents::Logging::NullLogger.instance }
    let(:tmpdir) { Dir.mktmpdir("logging_spec") }
    let(:raw_logger) { Smolagents::Logging::RawOutputLogger.new(directory: tmpdir) }

    after do
      raw_logger.close
      FileUtils.rm_rf(tmpdir)
    end

    it "NullLogger implements null? predicate" do
      expect(null_logger).to respond_to(:null?)
      expect(null_logger.null?).to be true
    end

    it "RawOutputLogger provides open? predicate" do
      expect(raw_logger).to respond_to(:open?)
      expect(raw_logger.open?).to be true
    end

    describe "method availability" do
      it "NullLogger has all standard log methods" do
        %i[debug info warn error].each do |method|
          expect(null_logger).to respond_to(method)
        end
      end

      it "NullLogger has step tracking methods" do
        %i[step_start step_complete step_error].each do |method|
          expect(null_logger).to respond_to(method)
        end
      end

      it "NullLogger has level accessors" do
        expect(null_logger).to respond_to(:level)
        expect(null_logger).to respond_to(:level=)
      end
    end
  end
end
