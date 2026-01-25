require "spec_helper"
require "smolagents/concerns/sandbox"

RSpec.describe Smolagents::Concerns::Sandbox do
  describe "namespace loader" do
    it "loads RubySafety module" do
      expect(defined?(Smolagents::Concerns::RubySafety)).to eq("constant")
    end

    it "loads SandboxMethods module" do
      expect(defined?(Smolagents::Concerns::SandboxMethods)).to eq("constant")
    end
  end
end
