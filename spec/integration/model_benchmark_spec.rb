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

      puts "\n#{"=" * 80}"
      puts "DISCOVERED MODELS"
      puts "=" * 80
      puts Smolagents::Testing::ModelCapabilities.header_line
      puts "-" * 80
      registry.each { |caps| puts caps.summary_line }
      puts "=" * 80
    end

    it "categorizes models by capability" do
      registry = self.class.models

      tool_models = registry.with_tool_use
      vision_models = registry.with_vision
      fast_models = registry.fast_models

      puts "\n--- Capability Summary ---"
      puts "Total models:      #{registry.size}"
      puts "With tool_use:     #{tool_models.size} (#{tool_models.ids.join(", ")})"
      puts "With vision:       #{vision_models.size} (#{vision_models.ids.join(", ")})"
      puts "Fast models:       #{fast_models.size} (#{fast_models.ids.join(", ")})"
      puts "-" * 30

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
      context "#{caps.model_id} (#{caps.param_count_str}, #{caps.architecture})" do
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
          when :medium then 3
          else 3
          end
        end

        it "passes expected test levels", :slow do
          summary = benchmark.run(model_id, levels: test_levels, timeout:)

          puts "\n#{summary.report}"

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

            puts "\n#{summary.report}"

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

      puts "\n>>> Testing #{testable.size} tool-capable models..."

      summaries = {}
      testable.each do |caps|
        timeout = caps.fast? ? 60 : 120

        puts "\n  → #{caps.model_id} (#{caps.param_count_str}, levels 1..5)..."
        summaries[caps.model_id] = benchmark.run(caps.model_id, levels: 1..5, timeout:)
      end

      puts "\n"
      puts Smolagents::Testing.comparison_table(summaries)

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

      puts "\n--- JSON Export ---"
      puts JSON.pretty_generate(export)
      puts "--- End Export ---"

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

      puts "\n--- Speed Comparison (Fast Models) ---"
      puts "#{"Model".ljust(30)}#{"Params".rjust(8)}#{"Arch".rjust(12)}#{"Time".rjust(10)}#{"Tok/s".rjust(10)}"
      puts "-" * 70
      results.sort_by { |r| -(r[:tps] || 0) }.each do |r|
        puts "#{r[:model].ljust(30)}#{r[:params].rjust(8)}#{r[:arch].to_s.rjust(12)}#{r[:duration].to_s.rjust(10)}#{r[:tps].to_s.rjust(10)}"
      end
      puts "-" * 70

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

      puts "\n--- Architecture Distribution ---"
      by_arch.each do |arch, models|
        puts "#{arch}: #{models.map(&:model_id).join(", ")}"
      end

      # Test one model per architecture
      summaries = {}
      by_arch.each do |arch, models|
        caps = models.first
        timeout = caps.fast? ? 60 : 120

        puts "\n>>> Testing #{arch} representative: #{caps.model_id}..."
        summaries[caps.model_id] = benchmark.run(caps.model_id, levels: 1..3, timeout:)
      end

      puts "\n--- Architecture Comparison ---"
      summaries.each do |id, summary|
        caps = registry[id]
        puts "#{caps.architecture.to_s.ljust(12)} | #{id.ljust(25)} | Level #{summary.max_level_passed} | #{summary.avg_tokens_per_second.round(0)} tok/s"
      end
      puts "-" * 70
    end
  end
end
