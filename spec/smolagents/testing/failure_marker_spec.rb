RSpec.describe Smolagents::Testing::FailureMarker do
  describe ".create" do
    it "creates a marker with error class and message" do
      marker = described_class.create(RuntimeError, "Test error")

      expect(marker.error_class).to eq(RuntimeError)
      expect(marker.message).to eq("Test error")
    end

    it "creates a marker with just error class" do
      marker = described_class.create(ArgumentError)

      expect(marker.error_class).to eq(ArgumentError)
      expect(marker.message).to be_nil
    end

    it "creates a marker with error instance" do
      error = StandardError.new("Instance error")
      marker = described_class.create(error)

      expect(marker.error_class).to eq(error)
    end
  end

  describe "#raise!" do
    it "raises error class with message" do
      marker = described_class.create(RuntimeError, "Custom message")

      expect { marker.raise! }.to raise_error(RuntimeError, "Custom message")
    end

    it "raises with default message when none provided" do
      marker = described_class.create(RuntimeError)

      expect { marker.raise! }.to raise_error(RuntimeError, "MockModel failure injection")
    end

    it "raises error instance directly" do
      error = ArgumentError.new("Instance message")
      marker = described_class.create(error)

      expect { marker.raise! }.to raise_error(ArgumentError, "Instance message")
    end

    it "preserves error backtrace from instance" do
      error = RuntimeError.new("With backtrace")
      error.set_backtrace(["test:1:in `method'"])
      marker = described_class.create(error)

      begin
        marker.raise!
      rescue RuntimeError => e
        expect(e.backtrace).to include("test:1:in `method'")
      end
    end
  end

  describe "#error_type?" do
    it "returns true for matching class" do
      marker = described_class.create(ArgumentError, "test")

      expect(marker.error_type?(ArgumentError)).to be true
    end

    it "returns true for parent class" do
      marker = described_class.create(ArgumentError, "test")

      expect(marker.error_type?(StandardError)).to be true
    end

    it "returns false for non-matching class" do
      marker = described_class.create(RuntimeError, "test")

      expect(marker.error_type?(ArgumentError)).to be false
    end

    it "works with error instances" do
      error = TypeError.new("instance")
      marker = described_class.create(error)

      expect(marker.error_type?(TypeError)).to be true
      expect(marker.error_type?(StandardError)).to be true
      expect(marker.error_type?(ArgumentError)).to be false
    end
  end

  describe "immutability" do
    it "is frozen after creation" do
      marker = described_class.create(RuntimeError, "test")

      expect(marker).to be_frozen
    end
  end
end
