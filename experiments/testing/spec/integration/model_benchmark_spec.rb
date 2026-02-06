RSpec.describe "Model Benchmark Suite", :integration, skip: !ENV["LIVE_MODEL_TESTS"] do
  let(:lm_studio_url) { ENV.fetch("LM_STUDIO_URL", "http://localhost:1234/v1") }
  let(:lm_studio_base) { ENV.fetch("LM_STUDIO_URL", "http://localhost:1234").sub(%r{/v1$}, "") }

  # Discover models once for the entire suite
  # Only make network calls when LIVE_MODEL_TESTS is set
  def self.discover_models
    return Smolagents::Testing::ModelRegistry.new({}) unless ENV["LIVE_MODEL_TESTS"]

    base_url = ENV.fetch("LM_STUDIO_URL", "http://localhost:1234").sub(%r{/v1$}, "")
    Smolagents::Testing::ModelRegistry.from_lm_studio(base_url)
  rescue StandardError => e
    warn "Could not discover models: #{e.message}"
    Smolagents::Testing::ModelRegistry.new({})
  end

  # Cache discovered models at class level
  @discovered_models = nil

  def self.models
    @models ||= discover_models
  end

  before(:all) do
    Smolagents::Telemetry::LoggingSubscriber.enable(level: :info)
  end

  after(:all) do
    Smolagents::Telemetry::LoggingSubscriber.disable
  end

  describe "Model Discovery" do
    it "discovers loaded models from LM Studio" do
      registry = self.class.models

      expect(registry).not_to be_empty

      expect(registry).to all(be_a(Smolagents::Testing::ModelCapability))
    end

    it "categorizes models by capability" do
      registry = self.class.models

      tool_models = registry.with_tool_use
      vision_models = registry.with_vision

      # All tool_use models should be flagged correctly
      tool_models.each { |caps| expect(caps.tool_use?).to be true }
      vision_models.each { |caps| expect(caps.vision?).to be true }
    end
  end

  # Dynamic test generation based on discovered models
  describe "Individual Model Benchmarks" do
    let(:benchmark) { Smolagents::Testing::ModelBenchmark.new(base_url: lm_studio_url) }

    # Generate tests dynamically for each discovered model
    models.each do |caps|
      context "with #{caps.model_id} (#{caps.architecture})" do
        let(:model_id) { caps.model_id }
        let(:capabilities) { caps }

        # Test all models through level 5 - let results show what they can do
        let(:test_levels) { 1..5 }

        # Single timeout for all models - no size-based differentiation
        let(:timeout) { 120 }

        it "passes expected test levels", :slow do
          summary = benchmark.run(model_id, levels: test_levels, timeout:)

          # All models should pass at least level 1
          msg = "Expected #{model_id} to pass at least level 1"
          msg += " (basic response)" unless caps.tool_use?
          expect(summary.max_level_passed).to be >= 1, msg
        end

        # Vision test for VLMs
        if caps.vision?
          it "can process images (level 6)", :slow, :vision do
            summary = benchmark.run(model_id, levels: 6..6, timeout:)

            expect(summary.results.first).not_to be_nil,
                                                 "Expected #{model_id} to complete vision test"
          end
        end
      end
    end
  end

  describe "Full Comparison", :slow do
    it "benchmarks all tool-capable models" do
      registry = self.class.models
      benchmark = Smolagents::Testing::ModelBenchmark.new(base_url: lm_studio_url, registry:)

      testable = registry.with_tool_use
      skip "No tool-capable models loaded" if testable.empty?

      summaries = {}
      testable.each do |caps|
        summaries[caps.model_id] = benchmark.run(caps.model_id, levels: 1..5, timeout: 120)
      end

      # At least one model should pass level 3
      max_level = summaries.values.map(&:max_level_passed).max
      expect(max_level).to be >= 3,
                           "Expected at least one model to pass level 3 (tool calling)"
    end

    it "exports results as structured data" do
      registry = self.class.models
      benchmark = Smolagents::Testing::ModelBenchmark.new(base_url: lm_studio_url, registry:)

      testable = registry.with_tool_use
      skip "No tool-capable models loaded" if testable.empty?

      summaries = testable.to_h do |caps|
        [caps.model_id, benchmark.run(caps.model_id, levels: 1..3, timeout: 120)]
      end

      export = {
        timestamp: Time.now.iso8601,
        model_count: summaries.size,
        models: summaries.transform_values(&:to_h)
      }

      expect(export[:models]).not_to be_empty
    end
  end

  describe "Architecture Analysis" do
    it "groups results by architecture" do
      registry = self.class.models
      benchmark = Smolagents::Testing::ModelBenchmark.new(base_url: lm_studio_url, registry:)

      testable = registry.with_tool_use
      skip "No tool-capable models loaded" if testable.empty?

      # Group by architecture
      by_arch = testable.group_by(&:architecture)

      by_arch.each do |arch, models|
        expect(models).not_to be_empty, "Architecture #{arch} should have models"
      end

      # Test one model per architecture
      summaries = {}
      by_arch.each_value do |models|
        caps = models.first
        summaries[caps.model_id] = benchmark.run(caps.model_id, levels: 1..3, timeout: 120)
      end

      summaries.each_key do |id|
        registry[id]
      end
    end
  end
end
