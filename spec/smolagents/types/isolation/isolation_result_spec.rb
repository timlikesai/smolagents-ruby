require "smolagents"

RSpec.describe Smolagents::Types::Isolation::IsolationResult do
  let(:metrics) { Smolagents::Types::Isolation::ResourceMetrics.new(duration_ms: 100, memory_bytes: 1024, output_bytes: 512) }
  let(:instance) { described_class.success(value: "test", metrics:) }

  it_behaves_like "a data type"

  describe "ISOLATION_STATUSES constant" do
    it "defines all valid statuses" do
      statuses = Smolagents::Types::Isolation::ISOLATION_STATUSES
      expect(statuses).to contain_exactly(:success, :timeout, :violation, :error)
    end

    it "is frozen" do
      expect(Smolagents::Types::Isolation::ISOLATION_STATUSES).to be_frozen
    end
  end

  describe ".success" do
    subject(:result) { described_class.success(value: "result", metrics:) }

    it "creates a success result" do
      expect(result.status).to eq(:success)
    end

    it "stores the value" do
      expect(result.value).to eq("result")
    end

    it "stores metrics" do
      expect(result.metrics).to eq(metrics)
    end

    it "has nil error" do
      expect(result.error).to be_nil
    end

    it "handles nil value" do
      result = described_class.success(value: nil, metrics:)
      expect(result.value).to be_nil
      expect(result.success?).to be true
    end

    it "handles complex value types" do
      result = described_class.success(value: { nested: [1, 2, 3] }, metrics:)
      expect(result.value).to eq({ nested: [1, 2, 3] })
    end
  end

  describe ".timeout" do
    subject(:result) { described_class.timeout(metrics:) }

    it "creates a timeout result" do
      expect(result.status).to eq(:timeout)
    end

    it "has nil value" do
      expect(result.value).to be_nil
    end

    it "stores metrics" do
      expect(result.metrics).to eq(metrics)
    end

    it "creates default TimeoutError" do
      expect(result.error).to be_a(Smolagents::Types::Isolation::TimeoutError)
      expect(result.error.message).to eq("Execution timed out")
    end

    it "accepts custom error" do
      custom_error = Smolagents::Types::Isolation::TimeoutError.new("Custom timeout message")
      result = described_class.timeout(metrics:, error: custom_error)
      expect(result.error.message).to eq("Custom timeout message")
    end
  end

  describe ".violation" do
    subject(:result) { described_class.violation(metrics:, error:) }

    let(:error) { StandardError.new("Memory limit exceeded") }

    it "creates a violation result" do
      expect(result.status).to eq(:violation)
    end

    it "has nil value" do
      expect(result.value).to be_nil
    end

    it "stores metrics" do
      expect(result.metrics).to eq(metrics)
    end

    it "stores the error" do
      expect(result.error).to eq(error)
      expect(result.error.message).to eq("Memory limit exceeded")
    end
  end

  describe ".error" do
    subject(:result) { described_class.error(error:, metrics:) }

    let(:error) { RuntimeError.new("Something went wrong") }

    it "creates an error result" do
      expect(result.status).to eq(:error)
    end

    it "has nil value" do
      expect(result.value).to be_nil
    end

    it "stores the error" do
      expect(result.error).to eq(error)
    end

    it "stores provided metrics" do
      expect(result.metrics).to eq(metrics)
    end

    context "without metrics" do
      subject(:result) { described_class.error(error:) }

      it "uses zero metrics" do
        expect(result.metrics).to eq(Smolagents::Types::Isolation::ResourceMetrics.zero)
      end
    end
  end

  describe "predicate methods" do
    describe "#success?" do
      it "returns true for success status" do
        result = described_class.success(value: "x", metrics:)
        expect(result.success?).to be true
      end

      it "returns false for other statuses" do
        %i[timeout violation error].each do |status|
          result = described_class.new(status:, value: nil, metrics:, error: nil)
          expect(result.success?).to be false
        end
      end
    end

    describe "#timeout?" do
      it "returns true for timeout status" do
        result = described_class.timeout(metrics:)
        expect(result.timeout?).to be true
      end

      it "returns false for other statuses" do
        %i[success violation error].each do |status|
          result = described_class.new(status:, value: nil, metrics:, error: nil)
          expect(result.timeout?).to be false
        end
      end
    end

    describe "#violation?" do
      it "returns true for violation status" do
        result = described_class.violation(metrics:, error: StandardError.new("test"))
        expect(result.violation?).to be true
      end

      it "returns false for other statuses" do
        %i[success timeout error].each do |status|
          result = described_class.new(status:, value: nil, metrics:, error: nil)
          expect(result.violation?).to be false
        end
      end
    end

    describe "#error?" do
      it "returns true for error status" do
        result = described_class.error(error: StandardError.new("test"), metrics:)
        expect(result.error?).to be true
      end

      it "returns false for other statuses" do
        %i[success timeout violation].each do |status|
          result = described_class.new(status:, value: nil, metrics:, error: nil)
          expect(result.error?).to be false
        end
      end
    end

    describe "#failed?" do
      it "returns false for success" do
        result = described_class.success(value: "x", metrics:)
        expect(result.failed?).to be false
      end

      it "returns true for all non-success statuses" do
        %i[timeout violation error].each do |status|
          result = described_class.new(status:, value: nil, metrics:, error: nil)
          expect(result.failed?).to be true
        end
      end
    end
  end

  describe "#to_h" do
    it "returns hash with all fields" do
      result = described_class.success(value: "test", metrics:)
      hash = result.to_h

      expect(hash.keys).to contain_exactly(:status, :value, :metrics, :error)
    end

    it "converts metrics to hash" do
      result = described_class.success(value: "test", metrics:)
      hash = result.to_h

      expect(hash[:metrics]).to be_a(Hash)
      expect(hash[:metrics][:duration_ms]).to eq(100)
    end

    it "extracts error message" do
      error = StandardError.new("Boom")
      result = described_class.error(error:, metrics:)
      hash = result.to_h

      expect(hash[:error]).to eq("Boom")
    end

    it "handles nil error" do
      result = described_class.success(value: "test", metrics:)
      hash = result.to_h

      expect(hash[:error]).to be_nil
    end
  end

  describe "pattern matching" do
    it "matches on status" do
      result = described_class.success(value: "test", metrics:)

      matched = case result
                in status: :success
                  "success"
                else
                  "other"
                end

      expect(matched).to eq("success")
    end

    it "matches with value extraction" do
      result = described_class.success(value: "extracted", metrics:)

      matched = case result
                in status: :success, value:
                  value
                else
                  nil
                end

      expect(matched).to eq("extracted")
    end

    it "matches timeout status" do
      result = described_class.timeout(metrics:)

      matched = case result
                in status: :timeout
                  "timed out"
                else
                  "other"
                end

      expect(matched).to eq("timed out")
    end

    it "matches on error with extraction" do
      err = StandardError.new("Error message")
      result = described_class.error(error: err, metrics:)

      matched = case result
                in status: :error, error: captured_error
                  captured_error.message
                else
                  "other"
                end

      expect(matched).to eq("Error message")
    end
  end

  describe "edge cases" do
    it "handles empty string value" do
      result = described_class.success(value: "", metrics:)
      expect(result.value).to eq("")
      expect(result.success?).to be true
    end

    it "handles complex nested value" do
      value = { key: [{ nested: "value" }], number: 42 }
      result = described_class.success(value:, metrics:)
      expect(result.value).to eq(value)
    end

    it "equality works correctly" do
      result1 = described_class.success(value: "x", metrics:)
      result2 = described_class.success(value: "x", metrics:)
      expect(result1).to eq(result2)
    end

    it "handles error without message" do
      error = StandardError.new
      result = described_class.error(error:, metrics:)
      hash = result.to_h
      expect(hash[:error]).to eq(error.message)
    end
  end

  describe "immutability" do
    it "is frozen" do
      expect(instance).to be_frozen
    end

    it "#with returns new instance" do
      updated = instance.with(value: "updated")
      expect(updated).to be_frozen
      expect(updated.value).to eq("updated")
      expect(instance.value).to eq("test")
    end
  end
end
