require "spec_helper"

RSpec.describe Smolagents::Concerns::Auditable, type: :integration do
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
        expect(instance.class.ancestors).to include(described_class)
        expect(instance.class.ancestors).to include(Smolagents::Concerns::Monitorable)
      end
    end
  end
end
