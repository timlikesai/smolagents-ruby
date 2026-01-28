RSpec.describe Smolagents::Concerns::Resilience::CapabilityDetection do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Resilience::CapabilityDetection

      def emit(event, **kwargs)
        # No-op for testing
      end
    end
  end

  let(:detector) { test_class.new }

  before do
    # Clear cache between tests
    test_class.capability_cache.clear
  end

  describe "#detect_capabilities" do
    it "detects capabilities from URL" do
      caps = detector.detect_capabilities(base_url: "https://llama-cpp-ultra.example.com/v1")
      expect(caps.supports_tools).to be true
      expect(caps.supports_json_object).to be true
      expect(caps.supports_json_schema).to be true
    end

    it "detects lm_studio capabilities from port 1234" do
      caps = detector.detect_capabilities(base_url: "http://localhost:1234/v1")
      expect(caps.supports_tools).to eq(:model_dependent)  # Native for Qwen 2.5, Llama 3.x
      expect(caps.supports_json_object).to be false        # Returns 400 error
      expect(caps.supports_json_schema).to be true         # Works with full schema
    end

    it "uses explicit server_type override" do
      caps = detector.detect_capabilities(
        base_url: "http://localhost:1234/v1",
        server_type: :llama_cpp
      )
      expect(caps.supports_tools).to be true
      expect(caps.supports_json_object).to be true
    end

    it "caches capabilities" do
      url = "http://test.example.com:1234/v1"
      caps1 = detector.detect_capabilities(base_url: url)
      caps2 = detector.detect_capabilities(base_url: url)

      expect(caps1.detected_at).to eq(caps2.detected_at)
    end
  end

  describe "#learn_from_error" do
    let(:error) do
      instance_double(Faraday::Error, response: { status: 400 }, message: "unknown parameter")
    end

    before do
      detector.detect_capabilities(base_url: "http://localhost:1234/v1")
    end

    it "updates cached capabilities on 400 error" do
      detector.learn_from_error(
        base_url: "http://localhost:1234/v1",
        error:,
        attempted_feature: :supports_json_object
      )

      caps = detector.cached_capabilities(base_url: "http://localhost:1234/v1")
      expect(caps.supports_json_object).to be false
      expect(caps.learned?).to be true
    end

    it "ignores non-400 errors" do
      non_400_error = instance_double(Faraday::Error, response: { status: 500 }, message: "server error")

      detector.learn_from_error(
        base_url: "http://localhost:1234/v1",
        error: non_400_error,
        attempted_feature: :supports_json_object
      )

      caps = detector.cached_capabilities(base_url: "http://localhost:1234/v1")
      expect(caps.base?).to be true
    end
  end

  describe "#clear_capability_cache" do
    it "clears specific URL" do
      detector.detect_capabilities(base_url: "http://localhost:1234/v1")
      detector.clear_capability_cache(base_url: "http://localhost:1234/v1")

      expect(detector.cached_capabilities(base_url: "http://localhost:1234/v1")).to be_nil
    end

    it "clears all cache" do
      detector.detect_capabilities(base_url: "http://localhost:1234/v1")
      detector.detect_capabilities(base_url: "http://localhost:8080/v1")
      detector.clear_capability_cache

      expect(detector.cached_capabilities(base_url: "http://localhost:1234/v1")).to be_nil
      expect(detector.cached_capabilities(base_url: "http://localhost:8080/v1")).to be_nil
    end
  end
end
