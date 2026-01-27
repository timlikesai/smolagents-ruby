RSpec.describe Smolagents::Testing::TestLogger do
  subject(:logger) { described_class.new }

  describe "#initialize" do
    it "defaults to info level" do
      expect(logger.level).to eq(:info)
    end

    it "defaults to not verbose" do
      expect(logger.verbose).to be false
    end

    it "accepts custom level" do
      logger = described_class.new(level: :debug)
      expect(logger.level).to eq(:debug)
    end

    it "accepts verbose option" do
      logger = described_class.new(verbose: true)
      expect(logger.verbose).to be true
    end
  end

  describe "#debug" do
    context "with debug level" do
      let(:logger) { described_class.new(level: :debug) }

      it "outputs message" do
        expect { logger.debug("test") }.to output("[DEBUG] test\n").to_stdout
      end
    end

    context "with info level" do
      it "does not output message" do
        expect { logger.debug("test") }.not_to output.to_stdout
      end
    end
  end

  describe "#info" do
    context "with info level" do
      it "outputs message" do
        expect { logger.info("test") }.to output("[INFO] test\n").to_stdout
      end
    end

    context "with warn level" do
      let(:logger) { described_class.new(level: :warn) }

      it "does not output message" do
        expect { logger.info("test") }.not_to output.to_stdout
      end
    end
  end

  describe "#warn" do
    context "with warn level" do
      let(:logger) { described_class.new(level: :warn) }

      it "outputs message" do
        expect { logger.warn("test") }.to output("[WARN] test\n").to_stdout
      end
    end

    context "with error level" do
      let(:logger) { described_class.new(level: :error) }

      it "does not output message" do
        expect { logger.warn("test") }.not_to output.to_stdout
      end
    end
  end

  describe "#error" do
    it "always outputs message" do
      expect { logger.error("test") }.to output("[ERROR] test\n").to_stdout
    end

    it "outputs even with any level" do
      logger = described_class.new(level: :error)
      expect { logger.error("test") }.to output("[ERROR] test\n").to_stdout
    end
  end

  describe "#step_start" do
    it "outputs step start message" do
      expect { logger.step_start(1) }.to output(/Step 1 starting/).to_stdout
    end

    it "does not output with warn level" do
      logger = described_class.new(level: :warn)
      expect { logger.step_start(1) }.not_to output.to_stdout
    end
  end

  describe "#step_complete" do
    it "outputs step complete message" do
      expect { logger.step_complete(1) }.to output(/Step 1 complete/).to_stdout
    end

    it "includes duration when provided" do
      expect { logger.step_complete(1, duration: 0.5) }.to output(/500ms/).to_stdout
    end
  end

  describe "#step_error" do
    it "outputs error message" do
      error = RuntimeError.new("oops")
      expect { logger.step_error(1, error) }.to output(/Step 1 ERROR: oops/).to_stdout
    end
  end

  describe "#null?" do
    it "returns false" do
      expect(logger.null?).to be false
    end
  end
end
