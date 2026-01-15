require "spec_helper"

RSpec.describe "Sync control request handling" do
  let(:control_requests) { Smolagents::Types::ControlRequests }
  let(:sync_behavior) { control_requests::SyncBehavior }
  let(:response_class) { control_requests::Response }

  # Test helper class that includes the execution module
  let(:executor_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::Execution

      # Make private method accessible for testing
      public :handle_sync_control_request, :raise_sync_error
    end
  end

  let(:executor) { executor_class.new }

  describe "SyncBehavior constants" do
    it "defines RAISE behavior" do
      expect(sync_behavior::RAISE).to eq(:raise)
    end

    it "defines DEFAULT behavior" do
      expect(sync_behavior::DEFAULT).to eq(:default)
    end

    it "defines APPROVE behavior" do
      expect(sync_behavior::APPROVE).to eq(:approve)
    end

    it "defines SKIP behavior" do
      expect(sync_behavior::SKIP).to eq(:skip)
    end
  end

  describe "UserInput" do
    it "defaults to :default sync_behavior" do
      request = control_requests::UserInput.create(prompt: "Which file?")
      expect(request.sync_behavior).to eq(:default)
    end

    it "supports default_value field" do
      request = control_requests::UserInput.create(prompt: "Format?", default_value: "json")
      expect(request.default_value).to eq("json")
    end

    context "with :default behavior and default_value set" do
      it "returns response with default_value" do
        request = control_requests::UserInput.create(prompt: "Format?", default_value: "json")
        response = executor.handle_sync_control_request(request)

        expect(response).to be_approved
        expect(response.value).to eq("json")
      end
    end

    context "with :default behavior and no default_value" do
      it "raises ControlFlowError" do
        request = control_requests::UserInput.create(prompt: "Format?")

        expect { executor.handle_sync_control_request(request) }
          .to raise_error(Smolagents::ControlFlowError)
      end
    end

    context "with :skip behavior override" do
      it "returns nil response" do
        request = control_requests::UserInput.create(
          prompt: "Format?",
          sync_behavior: sync_behavior::SKIP
        )
        response = executor.handle_sync_control_request(request)

        expect(response).to be_approved
        expect(response.value).to be_nil
      end
    end

    context "with :raise behavior override" do
      it "raises ControlFlowError" do
        request = control_requests::UserInput.create(
          prompt: "Format?",
          sync_behavior: sync_behavior::RAISE
        )

        expect { executor.handle_sync_control_request(request) }
          .to raise_error(Smolagents::ControlFlowError)
      end
    end
  end

  describe "SubAgentQuery" do
    it "defaults to :skip sync_behavior" do
      request = control_requests::SubAgentQuery.create(
        agent_name: "researcher",
        query: "Include older results?"
      )
      expect(request.sync_behavior).to eq(:skip)
    end

    context "with default :skip behavior" do
      it "returns nil response" do
        request = control_requests::SubAgentQuery.create(
          agent_name: "researcher",
          query: "Include older results?"
        )
        response = executor.handle_sync_control_request(request)

        expect(response).to be_approved
        expect(response.value).to be_nil
      end
    end

    context "with :raise behavior override" do
      it "raises ControlFlowError" do
        request = control_requests::SubAgentQuery.create(
          agent_name: "researcher",
          query: "Include older results?",
          sync_behavior: sync_behavior::RAISE
        )

        expect { executor.handle_sync_control_request(request) }
          .to raise_error(Smolagents::ControlFlowError)
      end
    end
  end

  describe "Confirmation" do
    context "when reversible (default)" do
      it "defaults to :approve sync_behavior" do
        request = control_requests::Confirmation.create(
          action: "create_backup",
          description: "Create backup file"
        )
        expect(request.sync_behavior).to eq(:approve)
        expect(request.reversible).to be true
      end

      it "auto-approves in sync mode" do
        request = control_requests::Confirmation.create(
          action: "create_backup",
          description: "Create backup file"
        )
        response = executor.handle_sync_control_request(request)

        expect(response).to be_approved
      end
    end

    context "when not reversible" do
      it "defaults to :raise sync_behavior" do
        request = control_requests::Confirmation.create(
          action: "delete_file",
          description: "Delete /tmp/old.json",
          reversible: false
        )
        expect(request.sync_behavior).to eq(:raise)
        expect(request.reversible).to be false
      end

      it "raises ControlFlowError in sync mode" do
        request = control_requests::Confirmation.create(
          action: "delete_file",
          description: "Delete /tmp/old.json",
          reversible: false
        )

        expect { executor.handle_sync_control_request(request) }
          .to raise_error(Smolagents::ControlFlowError)
      end

      it "has dangerous? predicate" do
        request = control_requests::Confirmation.create(
          action: "delete_file",
          description: "Delete permanently",
          reversible: false
        )
        expect(request.dangerous?).to be true
      end
    end

    context "with explicit sync_behavior override" do
      it "allows :approve for irreversible actions when explicitly set" do
        request = control_requests::Confirmation.create(
          action: "delete_file",
          description: "Delete /tmp/old.json",
          reversible: false,
          sync_behavior: sync_behavior::APPROVE
        )
        response = executor.handle_sync_control_request(request)

        expect(response).to be_approved
      end
    end
  end

  describe "#raise_sync_error" do
    it "raises ControlFlowError with request context" do
      request = control_requests::UserInput.create(prompt: "Test?")

      expect { executor.raise_sync_error(request) }
        .to raise_error(Smolagents::ControlFlowError) do |error|
          expect(error.request_type).to eq(:UserInput)
          expect(error.context).to include(:prompt)
        end
    end
  end

  describe "Response" do
    it "creates approval response" do
      response = response_class.approve(request_id: "abc")
      expect(response.approved?).to be true
      expect(response.denied?).to be false
    end

    it "creates denial response" do
      response = response_class.deny(request_id: "abc", reason: "User declined")
      expect(response.approved?).to be false
      expect(response.denied?).to be true
      expect(response.value).to eq("User declined")
    end

    it "creates response with value" do
      response = response_class.respond(request_id: "abc", value: "config.yml")
      expect(response.approved?).to be true
      expect(response.value).to eq("config.yml")
    end
  end
end
