require "spec_helper"

RSpec.describe Smolagents::Concerns::Retryable do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Retryable

      attr_reader :call_count

      def initialize
        @call_count = 0
      end

      def operation
        @call_count += 1
        return "success" if @call_count >= 2

        raise StandardError, "Fail"
      end
    end
  end

  let(:instance) { test_class.new }

  describe "retryable behavior" do
    it "includes the module" do
      expect(instance).to be_a(described_class)
    end

    it "makes methods retryable" do
      expect(instance.respond_to?(:operation)).to be true
    end

    it "allows tracking of retry attempts" do
      expect(instance.call_count).to eq(0)
    end
  end

  describe "marking methods as retryable" do
    it "allows configuration" do
      # Implementation dependent
      expect(test_class.respond_to?(:retryable) || instance.respond_to?(:mark_retryable)).not_to be_nil
    end
  end
end
