RSpec.describe Smolagents::Concerns::GenerationTimeout do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::GenerationTimeout

      # Expose private methods for testing
      public :with_generation_timeout, :initialize_generation_timeout
    end
  end

  let(:instance) { test_class.new }

  describe "#with_generation_timeout" do
    it "passes through when timeout not configured" do
      result = instance.with_generation_timeout { "response" }

      expect(result).to eq("response")
    end

    it "passes through when timeout is nil" do
      instance.initialize_generation_timeout(timeout: nil)

      result = instance.with_generation_timeout { "response" }

      expect(result).to eq("response")
    end

    it "passes through when timeout is zero" do
      instance.initialize_generation_timeout(timeout: 0)

      result = instance.with_generation_timeout { "response" }

      expect(result).to eq("response")
    end

    it "returns result when generation completes within timeout" do
      instance.initialize_generation_timeout(timeout: 5)

      result = instance.with_generation_timeout { "fast response" }

      expect(result).to eq("fast response")
    end

    it "propagates errors from generation", :slow do
      instance.initialize_generation_timeout(timeout: 5)

      expect do
        instance.with_generation_timeout { raise "API error" }
      end.to raise_error(RuntimeError, "API error")
    end

    it "raises TimeoutError when generation exceeds timeout", :slow do
      instance.initialize_generation_timeout(timeout: 0.01)
      gate = Queue.new

      expect do
        instance.with_generation_timeout(context: :step) { gate.pop }
      end.to raise_error(Smolagents::Errors::TimeoutError) { |e|
        expect(e.operation).to eq(:step)
        expect(e.duration).to eq(0.01)
      }

      gate.push(:release) # Clean up blocked thread
    end

    it "includes context in timeout error", :slow do
      instance.initialize_generation_timeout(timeout: 0.01)
      gate = Queue.new

      expect do
        instance.with_generation_timeout(context: :planning) { gate.pop }
      end.to raise_error(Smolagents::Errors::TimeoutError, /timed out/) { |e|
        expect(e.operation).to eq(:planning)
      }

      gate.push(:release)
    end

    it "defaults context to :step", :slow do
      instance.initialize_generation_timeout(timeout: 0.01)
      gate = Queue.new

      expect do
        instance.with_generation_timeout { gate.pop }
      end.to raise_error(Smolagents::Errors::TimeoutError) { |e|
        expect(e.operation).to eq(:step)
      }

      gate.push(:release)
    end
  end

  describe "#initialize_generation_timeout" do
    it "sets timeout to nil by default" do
      # No timeout configured — with_generation_timeout is a passthrough
      result = instance.with_generation_timeout { "no timeout" }

      expect(result).to eq("no timeout")
    end

    it "accepts numeric timeout" do
      instance.initialize_generation_timeout(timeout: 120)

      # Should not raise — timeout is configured but not triggered
      result = instance.with_generation_timeout { "ok" }

      expect(result).to eq("ok")
    end
  end

  describe "integration with agent builder" do
    it "threads generation_timeout through builder config" do
      config = Smolagents::Types::AgentConfig.create(generation_timeout: 60)

      expect(config.generation_timeout).to eq(60)
    end

    it "defaults to nil in AgentConfig" do
      config = Smolagents::Types::AgentConfig.default

      expect(config.generation_timeout).to be_nil
    end
  end
end
