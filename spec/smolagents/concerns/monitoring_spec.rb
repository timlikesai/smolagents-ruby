require "spec_helper"
require "smolagents/concerns/monitoring"

RSpec.describe Smolagents::Concerns::Monitoring do
  describe "namespace loader" do
    it "loads Auditable module" do
      expect(defined?(Smolagents::Concerns::Auditable)).to eq("constant")
    end

    it "loads Monitorable module" do
      expect(defined?(Smolagents::Concerns::Monitorable)).to eq("constant")
    end
  end
end
