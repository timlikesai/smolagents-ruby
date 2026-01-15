require "spec_helper"

RSpec.describe Smolagents::Types::ControlRequests do
  describe "DSL" do
    describe ".define_request" do
      it "creates a Data.define class with id and created_at" do
        expect(described_class::UserInput.members).to include(:id, :created_at)
      end

      it "includes the Request module" do
        request = described_class::UserInput.create(prompt: "test")
        expect(request.request?).to be true
      end

      it "generates unique IDs" do
        r1 = described_class::UserInput.create(prompt: "a")
        r2 = described_class::UserInput.create(prompt: "b")
        expect(r1.id).not_to eq(r2.id)
      end

      it "sets created_at timestamp" do
        request = described_class::UserInput.create(prompt: "test")
        expect(request.created_at).to be_within(1).of(Time.now)
      end

      it "applies defaults" do
        request = described_class::UserInput.create(prompt: "test")
        expect(request.context).to eq({})
        expect(request.options).to be_nil
        expect(request.timeout).to be_nil
      end

      it "freezes specified fields" do
        request = described_class::UserInput.create(prompt: "test", context: { key: "value" })
        expect(request.context).to be_frozen
      end

      it "generates predicate methods from lambdas" do
        with_options = described_class::UserInput.create(prompt: "test", options: %w[a b])
        without_options = described_class::UserInput.create(prompt: "test")
        expect(with_options.has_options?).to be true
        expect(without_options.has_options?).to be false
      end

      it "generates factory methods on the module" do
        expect(described_class).to respond_to(:user_input)
        expect(described_class).to respond_to(:sub_agent_query)
        expect(described_class).to respond_to(:confirmation)
      end
    end
  end

  describe "factory methods" do
    describe ".user_input" do
      it "creates UserInput request" do
        request = described_class.user_input(prompt: "Which file?", options: %w[a b])
        expect(request).to be_a(described_class::UserInput)
        expect(request.prompt).to eq("Which file?")
        expect(request.options).to eq(%w[a b])
      end
    end

    describe ".sub_agent_query" do
      it "creates SubAgentQuery request" do
        request = described_class.sub_agent_query(agent_name: "researcher", query: "Include old?")
        expect(request).to be_a(described_class::SubAgentQuery)
        expect(request.agent_name).to eq("researcher")
        expect(request.query).to eq("Include old?")
      end
    end

    describe ".confirmation" do
      it "creates Confirmation request" do
        request = described_class.confirmation(action: "delete", description: "Delete file")
        expect(request).to be_a(described_class::Confirmation)
        expect(request.action).to eq("delete")
        expect(request.description).to eq("Delete file")
      end
    end
  end

  describe "UserInput" do
    subject(:request) { described_class::UserInput.create(prompt: "What file?", options: %w[a.rb b.rb]) }

    it "has prompt" do
      expect(request.prompt).to eq("What file?")
    end

    it "has options" do
      expect(request.options).to eq(%w[a.rb b.rb])
    end

    it "supports pattern matching" do
      case request
      in { prompt:, options: }
        expect(prompt).to eq("What file?")
        expect(options).to eq(%w[a.rb b.rb])
      end
    end

    it "converts to hash" do
      hash = request.to_h
      expect(hash[:prompt]).to eq("What file?")
      expect(hash[:id]).to be_a(String)
    end

    describe "#has_options?" do
      it "returns true when options present" do
        expect(request.has_options?).to be true
      end

      it "returns false when options nil" do
        r = described_class::UserInput.create(prompt: "test")
        expect(r.has_options?).to be false
      end

      it "returns false when options empty" do
        r = described_class::UserInput.create(prompt: "test", options: [])
        expect(r.has_options?).to be false
      end
    end
  end

  describe "SubAgentQuery" do
    subject(:request) do
      described_class::SubAgentQuery.create(
        agent_name: "researcher",
        query: "Include old results?",
        options: %w[yes no]
      )
    end

    it "has agent_name" do
      expect(request.agent_name).to eq("researcher")
    end

    it "has query" do
      expect(request.query).to eq("Include old results?")
    end

    it "supports pattern matching" do
      case request
      in { agent_name:, query: }
        expect(agent_name).to eq("researcher")
        expect(query).to eq("Include old results?")
      end
    end

    describe "#has_options?" do
      it "returns true when options present" do
        expect(request.has_options?).to be true
      end

      it "returns false when options nil" do
        r = described_class::SubAgentQuery.create(agent_name: "test", query: "?")
        expect(r.has_options?).to be false
      end
    end
  end

  describe "Confirmation" do
    subject(:request) do
      described_class::Confirmation.create(
        action: "delete_file",
        description: "Delete /tmp/old.json",
        consequences: ["Data lost"],
        reversible: false
      )
    end

    it "has action" do
      expect(request.action).to eq("delete_file")
    end

    it "has description" do
      expect(request.description).to eq("Delete /tmp/old.json")
    end

    it "has consequences" do
      expect(request.consequences).to eq(["Data lost"])
    end

    it "has reversible flag" do
      expect(request.reversible).to be false
    end

    it "defaults reversible to true" do
      r = described_class::Confirmation.create(action: "test", description: "test")
      expect(r.reversible).to be true
    end

    describe "#dangerous?" do
      it "returns true when not reversible" do
        expect(request.dangerous?).to be true
      end

      it "returns false when reversible" do
        r = described_class::Confirmation.create(action: "test", description: "test", reversible: true)
        expect(r.dangerous?).to be false
      end
    end
  end

  describe "Response" do
    describe ".approve" do
      it "creates approved response" do
        response = described_class::Response.approve(request_id: "abc", value: "yes")
        expect(response.approved?).to be true
        expect(response.denied?).to be false
        expect(response.value).to eq("yes")
        expect(response.request_id).to eq("abc")
      end

      it "defaults value to nil" do
        response = described_class::Response.approve(request_id: "abc")
        expect(response.value).to be_nil
      end
    end

    describe ".deny" do
      it "creates denied response" do
        response = described_class::Response.deny(request_id: "abc", reason: "Not allowed")
        expect(response.denied?).to be true
        expect(response.approved?).to be false
        expect(response.value).to eq("Not allowed")
      end
    end

    describe ".respond" do
      it "creates response with value" do
        response = described_class::Response.respond(request_id: "abc", value: "config.yml")
        expect(response.approved?).to be true
        expect(response.value).to eq("config.yml")
      end
    end

    it "supports pattern matching" do
      response = described_class::Response.approve(request_id: "abc", value: "yes")
      case response
      in { request_id:, approved: true, value: }
        expect(request_id).to eq("abc")
        expect(value).to eq("yes")
      end
    end
  end

  describe "Request module" do
    it "provides request? predicate" do
      request = described_class::UserInput.create(prompt: "test")
      expect(request.request?).to be true
    end

    it "provides to_h method" do
      request = described_class::UserInput.create(prompt: "test")
      expect(request.to_h).to be_a(Hash)
      expect(request.to_h[:prompt]).to eq("test")
    end

    describe "#request_type" do
      it "returns :user_input for UserInput" do
        request = described_class::UserInput.create(prompt: "test")
        expect(request.request_type).to eq(:user_input)
      end

      it "returns :sub_agent_query for SubAgentQuery" do
        request = described_class::SubAgentQuery.create(agent_name: "test", query: "?")
        expect(request.request_type).to eq(:sub_agent_query)
      end

      it "returns :confirmation for Confirmation" do
        request = described_class::Confirmation.create(action: "test", description: "test")
        expect(request.request_type).to eq(:confirmation)
      end
    end
  end
end
