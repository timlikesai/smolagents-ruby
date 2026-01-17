RSpec.describe Smolagents::Interactive::Colors do
  describe "constants" do
    it "defines RESET" do
      expect(described_class::RESET).to eq("\e[0m")
    end

    it "defines BOLD" do
      expect(described_class::BOLD).to eq("\e[1m")
    end

    it "defines DIM" do
      expect(described_class::DIM).to eq("\e[2m")
    end

    it "defines color codes" do
      expect(described_class::GREEN).to eq("\e[32m")
      expect(described_class::YELLOW).to eq("\e[33m")
      expect(described_class::BLUE).to eq("\e[34m")
      expect(described_class::MAGENTA).to eq("\e[35m")
      expect(described_class::CYAN).to eq("\e[36m")
      expect(described_class::WHITE).to eq("\e[37m")
    end

    it "defines bright color codes" do
      expect(described_class::BRIGHT_GREEN).to eq("\e[92m")
      expect(described_class::BRIGHT_YELLOW).to eq("\e[93m")
      expect(described_class::BRIGHT_BLUE).to eq("\e[94m")
      expect(described_class::BRIGHT_CYAN).to eq("\e[96m")
    end

    it "freezes all constants" do
      expect(described_class::RESET).to be_frozen
      expect(described_class::BOLD).to be_frozen
      expect(described_class::GREEN).to be_frozen
    end
  end

  describe ".enabled?" do
    after { described_class.enabled = nil }

    it "defaults to $stdout.tty? when not explicitly set" do
      described_class.enabled = nil
      expect(described_class.enabled?).to eq($stdout.tty?)
    end

    it "returns true when explicitly enabled" do
      described_class.enabled = true
      expect(described_class.enabled?).to be true
    end

    it "returns false when explicitly disabled" do
      described_class.enabled = false
      expect(described_class.enabled?).to be false
    end
  end

  describe ".enabled=" do
    after { described_class.enabled = nil }

    it "allows setting enabled to true" do
      described_class.enabled = true
      expect(described_class.enabled?).to be true
    end

    it "allows setting enabled to false" do
      described_class.enabled = false
      expect(described_class.enabled?).to be false
    end

    it "allows resetting to nil" do
      described_class.enabled = true
      described_class.enabled = nil
      expect(described_class.enabled?).to eq($stdout.tty?)
    end
  end

  describe ".wrap" do
    context "when colors enabled" do
      before { described_class.enabled = true }
      after { described_class.enabled = nil }

      it "wraps text with a single color code" do
        result = described_class.wrap("hello", described_class::GREEN)
        expect(result).to eq("\e[32mhello\e[0m")
      end

      it "wraps text with multiple color codes" do
        result = described_class.wrap("hello", described_class::BOLD, described_class::GREEN)
        expect(result).to eq("\e[1m\e[32mhello\e[0m")
      end

      it "handles empty text" do
        result = described_class.wrap("", described_class::GREEN)
        expect(result).to eq("\e[32m\e[0m")
      end

      it "handles no codes" do
        result = described_class.wrap("hello")
        expect(result).to eq("hello\e[0m")
      end
    end

    context "when colors disabled" do
      before { described_class.enabled = false }
      after { described_class.enabled = nil }

      it "returns text unchanged" do
        result = described_class.wrap("hello", described_class::GREEN)
        expect(result).to eq("hello")
      end

      it "ignores multiple codes" do
        result = described_class.wrap("hello", described_class::BOLD, described_class::GREEN)
        expect(result).to eq("hello")
      end
    end
  end
end

RSpec.describe Smolagents::Interactive::ColorHelpers do
  let(:helper_class) do
    Class.new do
      extend Smolagents::Interactive::ColorHelpers
    end
  end

  before { Smolagents::Interactive::Colors.enabled = true }
  after { Smolagents::Interactive::Colors.enabled = nil }

  describe "#bold" do
    it "wraps text in bold" do
      expect(helper_class.bold("text")).to eq("\e[1mtext\e[0m")
    end
  end

  describe "#dim" do
    it "wraps text in dim" do
      expect(helper_class.dim("text")).to eq("\e[2mtext\e[0m")
    end
  end

  describe "#green" do
    it "wraps text in bright green" do
      expect(helper_class.green("text")).to eq("\e[92mtext\e[0m")
    end
  end

  describe "#yellow" do
    it "wraps text in yellow" do
      expect(helper_class.yellow("text")).to eq("\e[33mtext\e[0m")
    end
  end

  describe "#cyan" do
    it "wraps text in cyan" do
      expect(helper_class.cyan("text")).to eq("\e[36mtext\e[0m")
    end
  end

  describe "#magenta" do
    it "wraps text in magenta" do
      expect(helper_class.magenta("text")).to eq("\e[35mtext\e[0m")
    end
  end

  describe "#section" do
    it "wraps text in bold white" do
      expect(helper_class.section("title")).to eq("\e[1m\e[37mtitle\e[0m")
    end
  end
end
