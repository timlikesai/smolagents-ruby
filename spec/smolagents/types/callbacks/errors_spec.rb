require "spec_helper"

RSpec.describe Smolagents::Types::Callbacks::InvalidCallbackError do
  it "inherits from ArgumentError" do
    expect(described_class).to be < ArgumentError
  end

  it "can be raised with a message" do
    expect { raise described_class, "test message" }
      .to raise_error(described_class, "test message")
  end

  it "can be rescued as ArgumentError" do
    expect do
      raise described_class, "test"
    rescue ArgumentError
      # Rescued as expected
    end.not_to raise_error
  end

  it "can be instantiated" do
    error = described_class.new("invalid callback")
    expect(error.message).to eq("invalid callback")
  end
end

RSpec.describe Smolagents::Types::Callbacks::InvalidArgumentError do
  it "inherits from ArgumentError" do
    expect(described_class).to be < ArgumentError
  end

  it "can be raised with a message" do
    expect { raise described_class, "missing required argument" }
      .to raise_error(described_class, "missing required argument")
  end

  it "can be rescued as ArgumentError" do
    expect do
      raise described_class, "test"
    rescue ArgumentError
      # Rescued as expected
    end.not_to raise_error
  end

  it "can be instantiated" do
    error = described_class.new("wrong type")
    expect(error.message).to eq("wrong type")
  end

  describe "typical usage" do
    it "signals missing required arguments" do
      expect { raise described_class, "missing required arguments: step_number" }
        .to raise_error(described_class, /missing required arguments/)
    end

    it "signals type mismatch" do
      expect { raise described_class, "expected Integer, got String" }
        .to raise_error(described_class, /expected Integer/)
    end
  end
end
