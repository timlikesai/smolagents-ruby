RSpec.describe Smolagents::Testing::TestMode do
  after { described_class.disable! }

  describe ".test_mode?" do
    it "returns false by default" do
      described_class.disable!
      expect(described_class.test_mode?).to be false
    end

    it "returns true after enable!" do
      described_class.enable!
      expect(described_class.test_mode?).to be true
    end
  end

  describe ".enable!" do
    it "enables test mode" do
      described_class.enable!
      expect(described_class.test_mode?).to be true
    end

    it "returns self for chaining" do
      expect(described_class.enable!).to eq(described_class)
    end

    it "sets thread-local test mode flags" do
      described_class.enable!
      expect(Thread.current[:smolagents_test_mode]).to be true
    end
  end

  describe ".disable!" do
    it "disables test mode" do
      described_class.enable!
      described_class.disable!
      expect(described_class.test_mode?).to be false
    end

    it "returns self for chaining" do
      expect(described_class.disable!).to eq(described_class)
    end
  end

  describe ".scope" do
    it "enables test mode within block" do
      inside = nil
      described_class.scope { inside = described_class.test_mode? }
      expect(inside).to be true
    end

    it "disables test mode after block" do
      described_class.scope { nil }
      expect(described_class.test_mode?).to be false
    end

    it "restores previous state after block" do
      described_class.enable!
      described_class.scope { nil }
      expect(described_class.test_mode?).to be true
    end

    it "returns block result" do
      result = described_class.scope { "result" }
      expect(result).to eq("result")
    end

    it "restores state even on exception" do
      expect do
        described_class.scope { raise "oops" }
      end.to raise_error("oops")

      expect(described_class.test_mode?).to be false
    end
  end

  describe ".configuration" do
    it "returns a TestConfiguration" do
      expect(described_class.configuration).to be_a(Smolagents::Testing::TestConfiguration)
    end

    it "returns same instance on repeated calls" do
      config1 = described_class.configuration
      config2 = described_class.configuration
      expect(config1).to be(config2)
    end
  end

  describe ".configure" do
    it "yields configuration" do
      yielded = nil
      described_class.configure { |c| yielded = c }
      expect(yielded).to be(described_class.configuration)
    end

    it "returns self for chaining" do
      expect(described_class.configure { nil }).to eq(described_class)
    end
  end

  describe ".reset!" do
    it "creates a new configuration" do
      old = described_class.configuration
      described_class.reset!
      expect(described_class.configuration).not_to be(old)
    end

    it "returns self for chaining" do
      expect(described_class.reset!).to eq(described_class)
    end
  end
end

RSpec.describe Smolagents::Testing::TestConfiguration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "has verbose_logging disabled" do
      expect(config.verbose_logging).to be false
    end

    it "has record_call_logs enabled" do
      expect(config.record_call_logs).to be true
    end

    it "has skip_retry_delays enabled" do
      expect(config.skip_retry_delays).to be true
    end

    it "has default timeout of 5000ms" do
      expect(config.default_timeout_ms).to eq(5000)
    end
  end

  describe "setters" do
    it "allows setting verbose_logging" do
      config.verbose_logging = true
      expect(config.verbose_logging).to be true
    end

    it "allows setting record_call_logs" do
      config.record_call_logs = false
      expect(config.record_call_logs).to be false
    end

    it "allows setting skip_retry_delays" do
      config.skip_retry_delays = false
      expect(config.skip_retry_delays).to be false
    end

    it "allows setting default_timeout_ms" do
      config.default_timeout_ms = 10_000
      expect(config.default_timeout_ms).to eq(10_000)
    end
  end
end

RSpec.describe Smolagents do
  after { Smolagents::Testing::TestMode.disable! }

  describe ".test_mode!" do
    it "enables test mode" do
      described_class.test_mode!
      expect(described_class.test_mode?).to be true
    end
  end

  describe ".test_mode?" do
    it "returns test mode status" do
      expect(described_class.test_mode?).to be false
      described_class.test_mode!
      expect(described_class.test_mode?).to be true
    end
  end

  describe ".test_mode { }" do
    it "enables test mode in block" do
      inside = nil
      described_class.test_mode { inside = described_class.test_mode? }
      expect(inside).to be true
    end

    it "returns block result" do
      result = described_class.test_mode { 42 }
      expect(result).to eq(42)
    end
  end
end
