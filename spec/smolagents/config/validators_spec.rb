require "spec_helper"

RSpec.describe "Smolagents::Config::VALIDATORS" do
  subject(:validators) { Smolagents::Config::VALIDATORS }

  it "is frozen" do
    expect(validators).to be_frozen
  end

  describe ":log_format validator" do
    subject(:validator) { validators[:log_format] }

    it "accepts :text" do
      expect { validator.call(:text) }.not_to raise_error
    end

    it "accepts :json" do
      expect { validator.call(:json) }.not_to raise_error
    end

    it "rejects invalid values" do
      expect { validator.call(:yaml) }.to raise_error(ArgumentError, /log_format must be :text or :json/)
    end

    it "rejects string values" do
      expect { validator.call("text") }.to raise_error(ArgumentError)
    end
  end

  describe ":log_level validator" do
    subject(:validator) { validators[:log_level] }

    it "accepts :debug" do
      expect { validator.call(:debug) }.not_to raise_error
    end

    it "accepts :info" do
      expect { validator.call(:info) }.not_to raise_error
    end

    it "accepts :warn" do
      expect { validator.call(:warn) }.not_to raise_error
    end

    it "accepts :error" do
      expect { validator.call(:error) }.not_to raise_error
    end

    it "rejects invalid values" do
      expect { validator.call(:trace) }.to raise_error(ArgumentError, /log_level must be/)
    end
  end

  describe ":max_steps validator" do
    subject(:validator) { validators[:max_steps] }

    it "accepts nil" do
      expect { validator.call(nil) }.not_to raise_error
    end

    it "accepts positive integers" do
      expect { validator.call(1) }.not_to raise_error
      expect { validator.call(100) }.not_to raise_error
    end

    it "rejects zero" do
      expect { validator.call(0) }.to raise_error(ArgumentError, /max_steps must be positive/)
    end

    it "rejects negative values" do
      expect { validator.call(-1) }.to raise_error(ArgumentError, /max_steps must be positive/)
    end
  end

  describe ":custom_instructions validator" do
    subject(:validator) { validators[:custom_instructions] }

    it "accepts nil" do
      expect { validator.call(nil) }.not_to raise_error
    end

    it "accepts short strings" do
      expect { validator.call("Short instructions") }.not_to raise_error
    end

    it "accepts strings up to 10,000 chars" do
      expect { validator.call("a" * 10_000) }.not_to raise_error
    end

    it "rejects strings over 10,000 chars" do
      expect { validator.call("a" * 10_001) }.to raise_error(
        ArgumentError, /custom_instructions too long/
      )
    end
  end

  describe ":search_provider validator" do
    subject(:validator) { validators[:search_provider] }

    it "accepts :duckduckgo" do
      expect { validator.call(:duckduckgo) }.not_to raise_error
    end

    it "accepts :google" do
      expect { validator.call(:google) }.not_to raise_error
    end

    it "rejects invalid providers" do
      expect { validator.call(:yahoo) }.to raise_error(
        ArgumentError, /search_provider must be one of/
      )
    end
  end
end
