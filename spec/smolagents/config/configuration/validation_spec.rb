require "spec_helper"

RSpec.describe Smolagents::Config::Configuration::Validation do
  let(:config) { Smolagents::Config::Configuration.new }

  describe "#validate!" do
    it "returns true when all values are valid" do
      expect(config.validate!).to be true
    end

    it "raises ArgumentError for invalid log_format" do
      config.instance_variable_set(:@log_format, :invalid)

      expect { config.validate! }.to raise_error(ArgumentError, /log_format must be/)
    end

    it "raises ArgumentError for invalid log_level" do
      config.instance_variable_set(:@log_level, :invalid)

      expect { config.validate! }.to raise_error(ArgumentError, /log_level must be/)
    end

    it "raises ArgumentError for invalid max_steps" do
      config.instance_variable_set(:@max_steps, -1)

      expect { config.validate! }.to raise_error(ArgumentError, /max_steps must be positive/)
    end

    it "raises ArgumentError for invalid search_provider" do
      config.instance_variable_set(:@search_provider, :invalid)

      expect { config.validate! }.to raise_error(ArgumentError, /search_provider must be one of/)
    end
  end

  describe "#validate" do
    it "returns true when all values are valid" do
      expect(config.validate).to be true
    end

    it "returns false when values are invalid" do
      config.instance_variable_set(:@log_format, :invalid)

      expect(config.validate).to be false
    end

    it "does not raise exceptions" do
      config.instance_variable_set(:@log_format, :invalid)

      expect { config.validate }.not_to raise_error
    end
  end

  describe "#valid?" do
    it "is aliased to validate" do
      expect(config.method(:valid?)).to eq(config.method(:validate))
    end

    it "returns true for valid configuration" do
      expect(config).to be_valid
    end

    it "returns false for invalid configuration" do
      config.instance_variable_set(:@max_steps, 0)

      expect(config).not_to be_valid
    end
  end
end
