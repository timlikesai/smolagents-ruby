require "spec_helper"

RSpec.describe Smolagents::Types::ControlRequests::Request do
  let(:user_input) { Smolagents::Types::ControlRequests::UserInput.create(prompt: "Which file?") }
  let(:sub_agent_query) do
    Smolagents::Types::ControlRequests::SubAgentQuery.create(
      agent_name: "researcher",
      query: "Include old results?"
    )
  end
  let(:confirmation) do
    Smolagents::Types::ControlRequests::Confirmation.create(
      action: "delete",
      description: "Delete temp files"
    )
  end

  describe "#request?" do
    it "returns true for all request types" do
      expect(user_input.request?).to be true
      expect(sub_agent_query.request?).to be true
      expect(confirmation.request?).to be true
    end
  end

  describe "#to_h" do
    it "converts UserInput to hash" do
      hash = user_input.to_h
      expect(hash).to be_a(Hash)
      expect(hash[:prompt]).to eq("Which file?")
      expect(hash[:id]).to be_a(String)
      expect(hash[:created_at]).to be_a(Time)
    end

    it "converts SubAgentQuery to hash" do
      hash = sub_agent_query.to_h
      expect(hash[:agent_name]).to eq("researcher")
      expect(hash[:query]).to eq("Include old results?")
    end

    it "converts Confirmation to hash" do
      hash = confirmation.to_h
      expect(hash[:action]).to eq("delete")
      expect(hash[:description]).to eq("Delete temp files")
    end

    it "includes all fields" do
      hash = user_input.to_h
      expect(hash.keys).to include(:id, :prompt, :context, :options, :timeout, :default_value, :sync_behavior,
                                   :created_at)
    end
  end

  describe "#request_type" do
    it "returns :user_input for UserInput" do
      expect(user_input.request_type).to eq(:user_input)
    end

    it "returns :sub_agent_query for SubAgentQuery" do
      expect(sub_agent_query.request_type).to eq(:sub_agent_query)
    end

    it "returns :confirmation for Confirmation" do
      expect(confirmation.request_type).to eq(:confirmation)
    end
  end

  describe "pattern matching support" do
    it "supports case/in pattern matching with hash patterns" do
      result = case user_input
               in { prompt:, id: }
                 { prompt:, id: }
               end
      expect(result[:prompt]).to eq("Which file?")
      expect(result[:id]).to be_a(String)
    end

    it "supports deconstruct_keys" do
      keys = user_input.deconstruct_keys(%i[prompt id])
      expect(keys[:prompt]).to eq("Which file?")
      expect(keys[:id]).to be_a(String)
    end

    it "supports deconstruct_keys with nil for all keys" do
      keys = user_input.deconstruct_keys(nil)
      expect(keys).to be_a(Hash)
      expect(keys.size).to eq(8)
    end
  end
end
