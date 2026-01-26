require "spec_helper"
require "smolagents/concerns/isolation"

RSpec.describe Smolagents::Concerns::Isolation do
  describe "namespace loader" do
    it "loads FiberExecutor" do
      expect(defined?(Smolagents::Concerns::Isolation::FiberExecutor)).to eq("constant")
    end

    it "loads ThreadExecutor" do
      expect(defined?(Smolagents::Concerns::Isolation::ThreadExecutor)).to eq("constant")
    end

    it "loads ToolIsolation" do
      expect(defined?(Smolagents::Concerns::Isolation::ToolIsolation)).to eq("constant")
    end

    it "loads ViolationInfoBuilder" do
      expect(defined?(Smolagents::Concerns::Isolation::ViolationInfoBuilder)).to eq("constant")
    end
  end

  describe "integration" do
    let(:limits) { Smolagents::Types::Isolation::ResourceLimits.default }

    describe "FiberExecutor and ThreadExecutor interoperability" do
      it "both executors return compatible IsolationResult types" do
        fiber_result = Smolagents::Concerns::Isolation::FiberExecutor.execute(limits:) { 42 }
        thread_result = Smolagents::Concerns::Isolation::ThreadExecutor.execute(limits:) { 42 }

        expect(fiber_result.class).to eq(thread_result.class)
        expect(fiber_result.value).to eq(thread_result.value)
      end

      it "both executors capture errors consistently" do
        fiber_result = Smolagents::Concerns::Isolation::FiberExecutor.execute(limits:) { raise "boom" }
        thread_result = Smolagents::Concerns::Isolation::ThreadExecutor.execute(limits:) { raise "boom" }

        expect(fiber_result.success?).to eq(thread_result.success?)
        expect(fiber_result.error.class).to eq(thread_result.error.class)
      end
    end

    describe "ViolationInfoBuilder with ResourceMetrics" do
      it "builds violation info from metrics and limits" do
        metrics = Smolagents::Types::Isolation::ResourceMetrics.new(
          duration_ms: 10_000.0,
          memory_bytes: 10_000_000,
          output_bytes: 1000
        )
        limits = Smolagents::Types::Isolation::ResourceLimits.new(
          timeout_seconds: 5.0,
          max_memory_bytes: 50_000_000,
          max_output_bytes: 10_000
        )

        info = Smolagents::Concerns::Isolation::ViolationInfoBuilder.build("test_tool", metrics, limits)

        expect(info[:tool_name]).to eq("test_tool")
        expect(info[:resource_type]).to eq(:timeout)
        expect(info).to have_key(:limit_value)
        expect(info).to have_key(:actual_value)
        expect(info).to have_key(:message)
      end
    end
  end
end
