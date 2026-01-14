RSpec.describe "Model Benchmark Suite", skip: !ENV["LIVE_MODEL_TESTS"] do
  let(:lm_studio_url) { ENV.fetch("LM_STUDIO_URL", "http://localhost:1234/v1") }
  let(:lm_studio_base) { ENV.fetch("LM_STUDIO_URL", "http://localhost:1234").sub(%r{/v1$}, "") }

  # Discover models once for the entire suite
  def self.discover_models
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

  # rubocop:disable RSpec/BeforeAfterAll
  before(:all) do
    Smolagents::Telemetry::LoggingSubscriber.enable(level: :info)
  end

  after(:all) do
    Smolagents::Telemetry::LoggingSubscriber.disable
  end
  # rubocop:enable RSpec/BeforeAfterAll

  describe "Model Discovery" do
    it "discovers loaded models from LM Studio" do
      registry = self.class.models

      expect(registry).not_to be_empty

      registry.each { |caps|  }
    end

    it "categorizes models by capability" do
      registry = self.class.models

      tool_models = registry.with_tool_use
      vision_models = registry.with_vision
      registry.fast_models

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
      context "with #{caps.model_id} (#{caps.param_count_str}, #{caps.architecture})" do
        let(:model_id) { caps.model_id }
        let(:capabilities) { caps }

        # Test all models through level 5 - let results show what they can do
        let(:test_levels) { 1..5 }

        let(:timeout) do
          case caps.speed
          when :fast then 45
          when :medium then 90
          else 150
          end
        end

        let(:expected_min_level) do
          case caps.size_category
          when :tiny then 1
          when :small then 2
          else 3 # :medium, :large, and unknown default to level 3
          end
        end

        it "passes expected test levels", :slow do
          summary = benchmark.run(model_id, levels: test_levels, timeout:)

          # Expectations based on model capabilities
          if caps.tool_use?
            expect(summary.max_level_passed).to be >= expected_min_level,
                                                "Expected #{model_id} (#{caps.size_category}) to pass at least level #{expected_min_level}"
          else
            expect(summary.max_level_passed).to be >= 1,
                                                "Expected #{model_id} to pass at least level 1 (basic response)"
          end
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
        timeout = caps.fast? ? 60 : 120

        summaries[caps.model_id] = benchmark.run(caps.model_id, levels: 1..5, timeout:)
      end

      # At least one model should pass level 3
      max_level = summaries.values.map(&:max_level_passed).max
      expect(max_level).to be >= 3,
                           "Expected at least one model to pass level 3 (tool calling)"
    end

    it "exports results as structured data" do
      registry = self.class.models
      benchmark = Smolagents::Testing::ModelBenchmark.new(base_url: lm_studio_url, registry:)

      testable = registry.with_tool_use.select(&:fast?)
      skip "No fast tool-capable models loaded" if testable.empty?

      summaries = testable.to_h do |caps|
        [caps.model_id, benchmark.run(caps.model_id, levels: 1..3, timeout: 60)]
      end

      export = {
        timestamp: Time.now.iso8601,
        model_count: summaries.size,
        models: summaries.transform_values(&:to_h)
      }

      expect(export[:models]).not_to be_empty
    end
  end

  describe "Speed Benchmarks" do
    it "measures throughput for all fast models" do
      registry = self.class.models
      benchmark = Smolagents::Testing::ModelBenchmark.new(base_url: lm_studio_url)

      fast = registry.fast_models
      skip "No fast models loaded" if fast.empty?

      results = fast.map do |caps|
        summary = benchmark.run(caps.model_id, levels: 1..1, timeout: 30)
        result = summary.results.first

        {
          model: caps.model_id,
          params: caps.param_count_str,
          arch: caps.architecture,
          duration: result&.duration&.round(3),
          tokens: result&.tokens&.total_tokens,
          tps: result&.tokens_per_second&.round(1)
        }
      end

      results.sort_by { |r| -(r[:tps] || 0) }.each do |r|
      end

      expect(results.all? { |r| r[:duration] }).to be true
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
      end

      # Test one model per architecture
      summaries = {}
      by_arch.each_value do |models|
        caps = models.first
        timeout = caps.fast? ? 60 : 120

        summaries[caps.model_id] = benchmark.run(caps.model_id, levels: 1..3, timeout:)
      end

      summaries.each_key do |id|
        registry[id]
      end
    end
  end
end
