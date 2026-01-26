require "spec_helper"

RSpec.describe Smolagents::Types::ControlRequests::Response do
  describe "Data.define structure" do
    it "is a Data type" do
      expect(described_class.ancestors).to include(Data)
    end

    it "has request_id, value, and approved members" do
      expect(described_class.members).to eq(%i[request_id value approved])
    end
  end

  describe ".approve" do
    subject(:response) { described_class.approve(request_id: "abc-123", value: "proceed") }

    it "creates an approved response" do
      expect(response.approved).to be true
    end

    it "sets the request_id" do
      expect(response.request_id).to eq("abc-123")
    end

    it "sets the value" do
      expect(response.value).to eq("proceed")
    end

    it "defaults value to nil when not provided" do
      resp = described_class.approve(request_id: "abc-123")
      expect(resp.value).to be_nil
    end
  end

  describe ".deny" do
    subject(:response) { described_class.deny(request_id: "abc-123", reason: "Too risky") }

    it "creates a denied response" do
      expect(response.approved).to be false
    end

    it "sets the request_id" do
      expect(response.request_id).to eq("abc-123")
    end

    it "stores the reason in value" do
      expect(response.value).to eq("Too risky")
    end

    it "defaults reason to nil when not provided" do
      resp = described_class.deny(request_id: "abc-123")
      expect(resp.value).to be_nil
    end
  end

  describe ".respond" do
    subject(:response) { described_class.respond(request_id: "abc-123", value: "config.yml") }

    it "creates an approved response" do
      expect(response.approved).to be true
    end

    it "sets the value" do
      expect(response.value).to eq("config.yml")
    end

    it "sets the request_id" do
      expect(response.request_id).to eq("abc-123")
    end
  end

  describe "#approved?" do
    it "returns true for approved responses" do
      response = described_class.approve(request_id: "abc")
      expect(response.approved?).to be true
    end

    it "returns false for denied responses" do
      response = described_class.deny(request_id: "abc")
      expect(response.approved?).to be false
    end
  end

  describe "#denied?" do
    it "returns true for denied responses" do
      response = described_class.deny(request_id: "abc")
      expect(response.denied?).to be true
    end

    it "returns false for approved responses" do
      response = described_class.approve(request_id: "abc")
      expect(response.denied?).to be false
    end
  end

  describe "pattern matching support" do
    it "supports hash pattern matching" do
      response = described_class.approve(request_id: "abc", value: "yes")
      result = case response
               in { request_id:, approved: true, value: }
                 { request_id:, value: }
               end
      expect(result[:request_id]).to eq("abc")
      expect(result[:value]).to eq("yes")
    end

    it "matches denied responses" do
      response = described_class.deny(request_id: "xyz", reason: "No")
      result = case response
               in { approved: false, value: reason }
                 reason
               end
      expect(result).to eq("No")
    end
  end

  describe "immutability" do
    it "is frozen by default" do
      response = described_class.approve(request_id: "abc")
      expect(response).to be_frozen
    end

    it "cannot be modified after creation" do
      response = described_class.approve(request_id: "abc")
      expect { response.instance_variable_set(:@approved, false) }.to raise_error(FrozenError)
    end
  end
end
