require "spec_helper"

RSpec.describe Smolagents::Persistence::AgentManifestValidation do
  describe ".validate!" do
    let(:valid_data) do
      {
        version: "1.0",
        agent_class: "Smolagents::Agents::Agent",
        model: { class_name: "Smolagents::Model", model_id: "gpt-4", config: {} }
      }
    end

    it "passes for valid data" do
      expect { described_class.validate!(valid_data) }.not_to raise_error
    end

    it "raises InvalidManifestError for missing version" do
      data = valid_data.except(:version)

      expect { described_class.validate!(data) }.to raise_error(
        Smolagents::Persistence::InvalidManifestError,
        /missing version/
      )
    end

    it "raises InvalidManifestError for missing agent_class" do
      data = valid_data.except(:agent_class)

      expect { described_class.validate!(data) }.to raise_error(
        Smolagents::Persistence::InvalidManifestError,
        /missing agent_class/
      )
    end

    it "raises InvalidManifestError for missing model" do
      data = valid_data.except(:model)

      expect { described_class.validate!(data) }.to raise_error(
        Smolagents::Persistence::InvalidManifestError,
        /missing model/
      )
    end

    it "raises InvalidManifestError listing all missing fields" do
      data = { version: "1.0" }

      expect { described_class.validate!(data) }.to raise_error(
        Smolagents::Persistence::InvalidManifestError
      ) do |error|
        expect(error.message).to include("missing agent_class")
        expect(error.message).to include("missing model")
      end
    end

    it "raises VersionMismatchError for unsupported version" do
      data = valid_data.merge(version: "99.0")

      expect { described_class.validate!(data) }.to raise_error(
        Smolagents::Persistence::VersionMismatchError
      ) do |error|
        expect(error.got_version).to eq("99.0")
        expect(error.expected_version).to eq("1.0")
      end
    end
  end

  describe ".validate_agent_class!" do
    it "passes for allowlisted class" do
      expect do
        described_class.validate_agent_class!("Smolagents::Agents::Agent")
      end.not_to raise_error
    end

    it "raises UntrustedClassError for non-allowlisted class" do
      expect do
        described_class.validate_agent_class!("EvilAgent")
      end.to raise_error(Smolagents::Persistence::UntrustedClassError) do |error|
        expect(error.class_name).to eq("EvilAgent")
        expect(error.allowed_classes).to include("Smolagents::Agents::Agent")
      end
    end

    it "raises UntrustedClassError for arbitrary Ruby classes" do
      %w[Kernel Object File IO].each do |klass|
        expect do
          described_class.validate_agent_class!(klass)
        end.to raise_error(Smolagents::Persistence::UntrustedClassError)
      end
    end
  end
end
