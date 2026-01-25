require "spec_helper"

RSpec.describe Smolagents::Types::Callbacks::DEFINITIONS do
  it "is a frozen Hash" do
    expect(described_class).to be_a(Hash)
    expect(described_class).to be_frozen
  end

  it "contains expected event keys" do
    expected_events = %i[
      before_step
      after_step
      after_task
      on_max_steps
      after_monitor
      on_step_error
      on_tokens_tracked
    ]
    expect(described_class.keys).to match_array(expected_events)
  end

  describe "event specifications" do
    described_class.each do |event, spec|
      context event.to_s do
        it "has required array" do
          expect(spec[:required]).to be_an(Array)
        end

        it "has optional array" do
          expect(spec[:optional]).to be_an(Array)
        end

        it "has types hash" do
          expect(spec[:types]).to be_a(Hash)
        end

        it "has types for all required arguments" do
          spec[:required].each do |arg|
            expect(spec[:types]).to have_key(arg)
          end
        end
      end
    end
  end

  describe ":before_step" do
    let(:spec) { described_class[:before_step] }

    it "requires step_number" do
      expect(spec[:required]).to eq([:step_number])
    end

    it "has no optional args" do
      expect(spec[:optional]).to eq([])
    end

    it "expects step_number to be Integer" do
      expect(spec[:types][:step_number]).to eq(Integer)
    end
  end

  describe ":after_step" do
    let(:spec) { described_class[:after_step] }

    it "requires step" do
      expect(spec[:required]).to eq([:step])
    end

    it "has optional monitor" do
      expect(spec[:optional]).to eq([:monitor])
    end

    it "expects step to be ActionStep (deferred)" do
      expect(spec[:types][:step]).to eq("Types::ActionStep")
    end

    it "expects monitor to be union type with NilClass" do
      expect(spec[:types][:monitor]).to include(NilClass)
    end
  end

  describe ":after_task" do
    let(:spec) { described_class[:after_task] }

    it "requires result" do
      expect(spec[:required]).to eq([:result])
    end

    it "expects result to be RunResult (deferred)" do
      expect(spec[:types][:result]).to eq("Types::RunResult")
    end
  end

  describe ":on_max_steps" do
    let(:spec) { described_class[:on_max_steps] }

    it "requires step_count" do
      expect(spec[:required]).to eq([:step_count])
    end

    it "expects step_count to be Integer" do
      expect(spec[:types][:step_count]).to eq(Integer)
    end
  end

  describe ":after_monitor" do
    let(:spec) { described_class[:after_monitor] }

    it "requires step_name and monitor" do
      expect(spec[:required]).to eq(%i[step_name monitor])
    end

    it "expects step_name to be Symbol or String" do
      expect(spec[:types][:step_name]).to eq([Symbol, String])
    end
  end

  describe ":on_step_error" do
    let(:spec) { described_class[:on_step_error] }

    it "requires step_name, error, and monitor" do
      expect(spec[:required]).to eq(%i[step_name error monitor])
    end

    it "expects error to be StandardError" do
      expect(spec[:types][:error]).to eq(StandardError)
    end
  end

  describe ":on_tokens_tracked" do
    let(:spec) { described_class[:on_tokens_tracked] }

    it "requires usage" do
      expect(spec[:required]).to eq([:usage])
    end

    it "expects usage to be TokenUsage (deferred)" do
      expect(spec[:types][:usage]).to eq("Types::TokenUsage")
    end
  end
end

RSpec.describe Smolagents::Types::Callbacks::SignatureBuilder do
  describe ".build_all" do
    subject(:signatures) { described_class.build_all }

    it "returns a frozen Hash" do
      expect(signatures).to be_a(Hash)
      expect(signatures).to be_frozen
    end

    it "creates CallbackSignature for each event" do
      signatures.each_value do |sig|
        expect(sig).to be_a(Smolagents::Types::Callbacks::CallbackSignature)
      end
    end

    it "includes all defined events" do
      expect(signatures.keys).to match_array(Smolagents::Types::Callbacks::DEFINITIONS.keys)
    end
  end

  describe ".build_one" do
    subject(:signature) { described_class.build_one(spec) }

    let(:spec) do
      {
        required: %i[name count],
        optional: [:extra],
        types: { name: String, count: Integer }
      }
    end

    it "creates a CallbackSignature" do
      expect(signature).to be_a(Smolagents::Types::Callbacks::CallbackSignature)
    end

    it "sets required_args from spec" do
      expect(signature.required_args).to eq(%i[name count])
    end

    it "sets optional_args from spec" do
      expect(signature.optional_args).to eq([:extra])
    end

    it "sets arg_types from spec" do
      expect(signature.arg_types).to eq({ name: String, count: Integer })
    end
  end
end
