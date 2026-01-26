RSpec.describe Smolagents::Testing::ModelBenchmark do
  let(:logger) { instance_double(Logger) }
  let(:empty_registry) { Smolagents::Testing::ModelCapabilities::Registry.new({}) }
  let(:benchmark) { described_class.new(logger:, registry: empty_registry) }

  before do
    allow(logger).to receive(:info)
  end

  describe "initialization" do
    it "creates with default parameters" do
      # Provide registry to avoid HTTP call in load_registry
      benchmark = described_class.new(registry: empty_registry)

      expect(benchmark.base_url).to eq(Smolagents::Config::DEFAULT_LOCAL_API_URL)
      expect(benchmark.logger).to be_a(Logger)
    end

    it "uses provided base_url" do
      benchmark = described_class.new(base_url: "http://custom-url:8000", registry: empty_registry)

      expect(benchmark.base_url).to eq("http://custom-url:8000")
    end

    it "uses provided logger" do
      custom_logger = instance_double(Logger)
      benchmark = described_class.new(logger: custom_logger, registry: empty_registry)

      expect(benchmark.logger).to equal(custom_logger)
    end

    it "initializes registry from provided source" do
      expect(benchmark.registry).to be_a(Smolagents::Testing::ModelCapabilities::Registry)
    end

    it "uses provided registry" do
      custom_registry = Smolagents::Testing::ModelCapabilities::Registry.new({})
      benchmark = described_class.new(registry: custom_registry)

      expect(benchmark.registry).to equal(custom_registry)
    end
  end

  describe "#run" do
    let(:mock_results) do
      [
        Smolagents::Testing::BenchmarkResult.success(
          model_id: "test-model",
          test_name: "basic_math",
          level: 1,
          duration: 2.5,
          tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
        ),
        Smolagents::Testing::BenchmarkResult.success(
          model_id: "test-model",
          test_name: "tool_use",
          level: 3,
          duration: 3.5,
          tokens: Smolagents::Types::TokenUsage.new(input_tokens: 150, output_tokens: 75)
        )
      ]
    end

    before do
      allow(benchmark).to receive(:run_levels).and_return(mock_results)
    end

    it "returns a BenchmarkSummary" do
      result = benchmark.run("test-model")

      expect(result).to be_a(Smolagents::Testing::BenchmarkSummary)
    end

    it "calls run_levels with provided parameters" do
      allow(benchmark).to receive(:run_levels).and_return(mock_results)
      benchmark.run("test-model")
      expect(benchmark).to have_received(:run_levels)
        .with("test-model", 1..5, timeout: 60, runs: 1, pass_threshold: 0.5)
    end

    it "accepts custom levels range" do
      allow(benchmark).to receive(:run_levels).and_return(mock_results)
      benchmark.run("test-model", levels: 1..3)
      expect(benchmark).to have_received(:run_levels)
        .with("test-model", 1..3, timeout: 60, runs: 1, pass_threshold: 0.5)
    end

    it "accepts custom timeout" do
      allow(benchmark).to receive(:run_levels).and_return(mock_results)
      benchmark.run("test-model", timeout: 120)
      expect(benchmark).to have_received(:run_levels)
        .with("test-model", 1..5, timeout: 120, runs: 1, pass_threshold: 0.5)
    end

    it "accepts custom runs count" do
      allow(benchmark).to receive(:run_levels).and_return(mock_results)
      benchmark.run("test-model", runs: 3)
      expect(benchmark).to have_received(:run_levels)
        .with("test-model", 1..5, timeout: 60, runs: 3, pass_threshold: 0.5)
    end

    it "accepts custom pass_threshold" do
      allow(benchmark).to receive(:run_levels).and_return(mock_results)
      benchmark.run("test-model", pass_threshold: 0.75)
      expect(benchmark).to have_received(:run_levels)
        .with("test-model", 1..5, timeout: 60, runs: 1, pass_threshold: 0.75)
    end

    it "includes capabilities from registry in summary" do
      capability = instance_double(Smolagents::Testing::ModelCapabilities::Capability)
      allow(benchmark.registry).to receive(:[]).with("test-model").and_return(capability)

      result = benchmark.run("test-model")

      expect(result.capabilities).to equal(capability)
    end
  end

  describe "#run_all_models" do
    let(:capability1) do
      instance_double(
        Smolagents::Testing::ModelCapabilities::Capability,
        model_id: "model-1",
        vision?: false
      )
    end

    let(:capability2) do
      instance_double(
        Smolagents::Testing::ModelCapabilities::Capability,
        model_id: "model-2",
        vision?: true
      )
    end

    let(:registry) do
      instance_double(
        Smolagents::Testing::ModelCapabilities::Registry
      )
    end

    before do
      allow(registry).to receive(:each).and_yield(capability1).and_yield(capability2)
      allow(benchmark).to receive_messages(registry:, run: instance_double(Smolagents::Testing::BenchmarkSummary))
    end

    it "runs benchmark on all models in registry" do
      allow(benchmark).to receive(:run).and_return(instance_double(Smolagents::Testing::BenchmarkSummary))
      benchmark.run_all_models(registry)
      expect(benchmark).to have_received(:run).twice
    end

    it "limits levels based on model vision capability" do
      allow(registry).to receive(:each).and_yield(capability1).and_yield(capability2)
      summary = instance_double(Smolagents::Testing::BenchmarkSummary)
      allow(benchmark).to receive(:run).and_return(summary)

      benchmark.run_all_models(registry, levels: 1..6)

      expect(benchmark).to have_received(:run).with("model-1", levels: [1, 2, 3, 4, 5])
      expect(benchmark).to have_received(:run).with("model-2", levels: [1, 2, 3, 4, 5, 6])
    end

    it "returns hash of model_id to summary" do
      allow(registry).to receive(:each).and_yield(capability1).and_yield(capability2)
      summary1 = instance_double(Smolagents::Testing::BenchmarkSummary)
      summary2 = instance_double(Smolagents::Testing::BenchmarkSummary)

      allow(benchmark).to receive(:run).and_return(summary1, summary2)

      result = benchmark.run_all_models(registry)

      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly("model-1", "model-2")
    end

    it "logs benchmark progress" do
      allow(registry).to receive(:each).and_yield(capability1)
      allow(logger).to receive(:info)

      benchmark.run_all_models(registry)

      expect(logger).to have_received(:info).with(/Benchmarking model-1/)
    end
  end

  describe "module inclusion" do
    it "includes TestDefinitions" do
      expect(described_class).to include(described_class::TestDefinitions)
    end

    it "includes BenchmarkTools" do
      expect(described_class).to include(described_class::BenchmarkTools)
    end

    it "includes Runner" do
      expect(described_class).to include(described_class::Runner)
    end

    it "includes Aggregator" do
      expect(described_class).to include(described_class::Aggregator)
    end
  end

  describe "logger initialization" do
    it "creates default logger with INFO level" do
      benchmark = described_class.new(logger: nil, registry: empty_registry)

      expect(benchmark.logger).to be_a(Logger)
      expect(benchmark.logger.level).to eq(Logger::INFO)
    end
  end
end
