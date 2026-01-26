require "spec_helper"

RSpec.describe Smolagents::Types::ControlRequests do
  describe "REQUEST_DEFINITIONS" do
    subject(:definitions) { described_class::REQUEST_DEFINITIONS }

    it "is frozen" do
      expect(definitions).to be_frozen
    end

    it "defines UserInput, SubAgentQuery, and Confirmation" do
      expect(definitions.keys).to contain_exactly(:UserInput, :SubAgentQuery, :Confirmation)
    end

    describe "UserInput definition" do
      subject(:user_input) { definitions[:UserInput] }

      it "has expected fields" do
        expect(user_input[:fields]).to eq(%i[prompt context options timeout default_value sync_behavior])
      end

      it "has expected defaults" do
        expect(user_input[:defaults]).to include(
          context: {},
          options: nil,
          timeout: nil,
          default_value: nil
        )
      end

      it "freezes context and options" do
        expect(user_input[:freeze]).to eq(%i[context options])
      end

      it "has has_options predicate" do
        expect(user_input[:predicates]).to have_key(:has_options)
      end

      it "has documentation" do
        expect(user_input[:doc]).to include("Request for user input")
      end
    end

    describe "SubAgentQuery definition" do
      subject(:sub_agent_query) { definitions[:SubAgentQuery] }

      it "has expected fields" do
        expect(sub_agent_query[:fields]).to eq(%i[agent_name query context options sync_behavior])
      end

      it "defaults sync_behavior to SKIP" do
        expect(sub_agent_query[:defaults][:sync_behavior]).to eq(
          Smolagents::Types::ControlRequests::SyncBehavior::SKIP
        )
      end
    end

    describe "Confirmation definition" do
      subject(:confirmation) { definitions[:Confirmation] }

      it "has expected fields" do
        expect(confirmation[:fields]).to eq(%i[action description consequences reversible sync_behavior])
      end

      it "defaults reversible to true" do
        expect(confirmation[:defaults][:reversible]).to be true
      end

      it "has dangerous predicate" do
        expect(confirmation[:predicates]).to have_key(:dangerous)
      end
    end
  end

  describe "DefinitionLoader" do
    describe ".load" do
      it "defines request types on the module" do
        expect(described_class.const_defined?(:UserInput)).to be true
        expect(described_class.const_defined?(:SubAgentQuery)).to be true
        expect(described_class.const_defined?(:Confirmation)).to be true
      end

      it "defines factory methods on the module" do
        expect(described_class).to respond_to(:user_input)
        expect(described_class).to respond_to(:sub_agent_query)
        expect(described_class).to respond_to(:confirmation)
      end
    end

    describe "Confirmation sync_behavior override" do
      it "sets APPROVE for reversible confirmations" do
        request = described_class::Confirmation.create(
          action: "test",
          description: "test",
          reversible: true
        )
        expect(request.sync_behavior).to eq(
          Smolagents::Types::ControlRequests::SyncBehavior::APPROVE
        )
      end

      it "sets RAISE for non-reversible confirmations" do
        request = described_class::Confirmation.create(
          action: "test",
          description: "test",
          reversible: false
        )
        expect(request.sync_behavior).to eq(
          Smolagents::Types::ControlRequests::SyncBehavior::RAISE
        )
      end

      it "respects explicitly set sync_behavior" do
        request = described_class::Confirmation.create(
          action: "test",
          description: "test",
          reversible: true,
          sync_behavior: Smolagents::Types::ControlRequests::SyncBehavior::SKIP
        )
        expect(request.sync_behavior).to eq(
          Smolagents::Types::ControlRequests::SyncBehavior::SKIP
        )
      end
    end
  end
end
