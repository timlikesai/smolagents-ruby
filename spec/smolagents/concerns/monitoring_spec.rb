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

  describe "integration" do
    describe "Auditable and Monitorable together" do
      let(:monitored_class) do
        Class.new do
          include Smolagents::Concerns::Auditable
          include Smolagents::Concerns::Monitorable

          def initialize
            @audit_log = []
          end
        end
      end

      it "can include both modules without conflict" do
        instance = monitored_class.new

        # Both modules should be included
        expect(instance.class.ancestors).to include(Smolagents::Concerns::Auditable)
        expect(instance.class.ancestors).to include(Smolagents::Concerns::Monitorable)
      end
    end
  end
end
