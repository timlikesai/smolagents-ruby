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
end
