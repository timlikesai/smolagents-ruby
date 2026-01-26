RSpec.describe Smolagents::Concerns::Isolation::ToolIsolation do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Isolation::ToolIsolation
    end
  end

  let(:instance) { test_class.new }
  let(:default_limits) { Smolagents::Types::Isolation::ResourceLimits.default }
  let(:short_timeout_limits) { Smolagents::Types::Isolation::ResourceLimits.with_timeout(0.005) }

  describe ".default_limits" do
    it "returns default resource limits" do
      limits = described_class.default_limits
      expect(limits).to be_a(Smolagents::Types::Isolation::ResourceLimits)
      expect(limits.timeout_seconds).to eq(5.0)
    end
  end

  describe "#with_tool_isolation" do
    it "executes block and returns result" do
      result = instance.with_tool_isolation(tool_name: "test") { "success" }
      expect(result).to eq("success")
    end

    it "accepts custom limits" do
      limits = Smolagents::Types::Isolation::ResourceLimits.with_timeout(10.0)
      result = instance.with_tool_isolation(tool_name: "test", limits:) { 42 }
      expect(result).to eq(42)
    end

    context "when timeout occurs" do
      it "raises TimeoutError", max_time: 0.15 do
        expect do
          # Block that yields to allow interruption during timeout
          instance.with_tool_isolation(tool_name: "slow", limits: short_timeout_limits) { loop { Thread.pass } }
        end.to raise_error(Smolagents::Types::Isolation::TimeoutError)
      end

      it "calls on_timeout callback before raising", max_time: 0.15 do
        timeout_info = nil
        begin
          instance.with_tool_isolation(
            tool_name: "slow",
            limits: short_timeout_limits,
            on_timeout: ->(info) { timeout_info = info }
          ) { loop { Thread.pass } }
        rescue Smolagents::Types::Isolation::TimeoutError
          # Expected
        end

        expect(timeout_info).to be_a(Hash)
        expect(timeout_info[:tool_name]).to eq("slow")
        expect(timeout_info[:error]).to be_a(Smolagents::Types::Isolation::TimeoutError)
      end
    end

    context "when block raises error" do
      it "propagates the error" do
        expect do
          instance.with_tool_isolation(tool_name: "error") { raise "boom" }
        end.to raise_error(RuntimeError, "boom")
      end
    end
  end
end
