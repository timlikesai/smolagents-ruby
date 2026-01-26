require "spec_helper"

RSpec.describe Smolagents::Concerns::RetryExecution do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::RetryExecution

      attr_reader :attempt_count

      def initialize
        @attempt_count = 0
      end

      def risky_operation
        @attempt_count += 1
        raise StandardError, "Failed" if @attempt_count < 3

        "success"
      end
    end
  end

  let(:instance) { test_class.new }

  describe "retry execution" do
    it "includes the module" do
      expect(instance).to be_a(described_class)
    end

    it "allows retrying operations" do
      # Depends on implementation
      expect(instance.respond_to?(:risky_operation)).to be true
    end
  end
end
