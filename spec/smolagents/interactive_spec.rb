require "smolagents/interactive"
require "smolagents/discovery"

RSpec.describe Smolagents::Interactive do
  before do
    # Stub all local server requests to avoid real network calls
    stub_request(:get, /localhost:\d+/).to_return(status: 404, body: "")
    stub_request(:get, /127\.0\.0\.1:\d+/).to_return(status: 404, body: "")
  end

  describe Smolagents::Interactive::Colors do
    describe ".enabled?" do
      it "defaults based on TTY status" do
        # In test environment, stdout may or may not be a TTY
        expect(described_class.enabled?).to be(true).or be(false)
      end

      it "can be explicitly set" do
        original = described_class.instance_variable_get(:@enabled)
        described_class.enabled = true
        expect(described_class.enabled?).to be true

        described_class.enabled = false
        expect(described_class.enabled?).to be false

        # Restore
        described_class.instance_variable_set(:@enabled, original)
      end
    end

    describe ".wrap" do
      before { described_class.enabled = true }
      after { described_class.enabled = nil }

      it "wraps text with color codes when enabled" do
        result = described_class.wrap("hello", described_class::GREEN)
        expect(result).to start_with("\e[32m")
        expect(result).to end_with("\e[0m")
        expect(result).to include("hello")
      end

      it "returns plain text when disabled" do
        described_class.enabled = false
        result = described_class.wrap("hello", described_class::GREEN)
        expect(result).to eq("hello")
      end

      it "combines multiple codes" do
        result = described_class.wrap("hello", described_class::BOLD, described_class::GREEN)
        expect(result).to start_with("\e[1m\e[32m")
      end
    end
  end

  describe ".session?" do
    it "returns false in test environment (no IRB/Pry)" do
      # Remove cached value to force fresh detection
      described_class.remove_instance_variable(:@session) if described_class.instance_variable_defined?(:@session)
      expect(described_class.session?).to be false
    end

    it "caches the result" do
      described_class.remove_instance_variable(:@session) if described_class.instance_variable_defined?(:@session)
      first = described_class.session?
      second = described_class.session?
      expect(first).to eq(second)
    end
  end

  describe ".colors?" do
    it "delegates to Colors.enabled?" do
      expect(described_class.colors?).to eq(Smolagents::Interactive::Colors.enabled?)
    end
  end

  describe ".activated?" do
    it "returns false by default" do
      # Reset state for test
      described_class.instance_variable_set(:@activated, nil)
      expect(described_class.activated?).to be false
    end
  end

  describe ".activate!" do
    before do
      described_class.instance_variable_set(:@activated, nil)
      # Suppress output during tests
      allow($stdout).to receive(:puts)
    end

    it "marks the module as activated" do
      described_class.activate!(quiet: true, scan: false)
      expect(described_class.activated?).to be true
    end

    it "returns discovery result when scan is true" do
      result = described_class.activate!(quiet: true, scan: true)
      expect(result).to be_a(Smolagents::Discovery::Result)
    end

    it "returns nil when scan is false" do
      result = described_class.activate!(quiet: true, scan: false)
      expect(result).to be_nil
    end
  end

  describe ".help" do
    before { allow($stdout).to receive(:puts) }

    it "shows general help by default" do
      expect { described_class.help }.not_to raise_error
    end

    it "shows models help" do
      expect { described_class.help(:models) }.not_to raise_error
    end

    it "shows tools help" do
      expect { described_class.help(:tools) }.not_to raise_error
    end

    it "shows agents help" do
      expect { described_class.help(:agents) }.not_to raise_error
    end

    it "shows discovery help" do
      expect { described_class.help(:discovery) }.not_to raise_error
    end

    it "handles unknown topics" do
      expect { described_class.help(:unknown) }.not_to raise_error
    end
  end

  describe ".models" do
    before { allow($stdout).to receive(:puts) }

    it "returns an array of models" do
      result = described_class.models
      expect(result).to be_an(Array)
    end

    it "can force a refresh" do
      described_class.instance_variable_set(:@last_discovery, nil)
      result = described_class.models(refresh: true)
      expect(result).to be_an(Array)
    end
  end

  describe ".default_handlers" do
    it "returns a hash of event handlers" do
      handlers = described_class.default_handlers
      expect(handlers).to be_a(Hash)
      expect(handlers.keys).to include(:tool_call, :tool_complete, :step_complete)
    end

    it "handlers are callable" do
      handlers = described_class.default_handlers
      handlers.each_value do |handler|
        expect(handler).to respond_to(:call)
      end
    end
  end

  describe ".agent" do
    it "returns a builder with handlers attached" do
      builder = described_class.agent
      expect(builder).to respond_to(:model)
      expect(builder).to respond_to(:tools)
      expect(builder).to respond_to(:build)
    end
  end

  describe "event handler formatting" do
    let(:step_event) do
      double(step_number: 1, outcome: :success)
    end

    let(:tool_event) do
      double(tool_name: "search", arguments: { query: "test" }, result: "Found results")
    end

    it "formats tool call" do
      line = described_class.send(:tool_call_line, tool_event)
      expect(line).to include("search")
    end

    it "formats tool result" do
      line = described_class.send(:tool_result_line, tool_event)
      expect(line).to include("Found results")
    end

    it "truncates long results" do
      long_event = double(result: "x" * 200)
      line = described_class.send(:tool_result_line, long_event)
      expect(line).to include("...")
      expect(line.length).to be < 200
    end

    it "formats step complete" do
      line = described_class.send(:step_complete_line, step_event)
      expect(line).to include("Step 1")
      expect(line).to include("✓")
    end
  end
end
