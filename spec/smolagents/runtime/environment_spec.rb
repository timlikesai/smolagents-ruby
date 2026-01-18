require "spec_helper"

RSpec.describe Smolagents::Runtime::Environment do
  describe ".standalone" do
    it "creates environment with empty context by default" do
      env = described_class.standalone
      expect(env.context).to eq({})
    end

    it "creates environment with provided context" do
      env = described_class.standalone(context: { task: "research" })
      expect(env.context).to eq({ task: "research" })
    end

    it "freezes the context" do
      env = described_class.standalone(context: { key: "value" })
      expect(env.context).to be_frozen
    end

    it "has empty capabilities" do
      env = described_class.standalone
      expect(env.capabilities).to be_empty
    end

    it "has no parent fiber" do
      env = described_class.standalone
      expect(env.parent_fiber).to be_nil
    end
  end

  describe ".for_child" do
    it "creates environment with context" do
      env = described_class.for_child(context: { agent_name: "researcher" })
      expect(env.context).to eq({ agent_name: "researcher" })
    end

    it "freezes the context" do
      env = described_class.for_child(context: { key: "value" })
      expect(env.context).to be_frozen
    end

    it "converts capabilities array to Set" do
      env = described_class.for_child(context: {}, capabilities: %i[search summarize])
      expect(env.capabilities).to be_a(Set)
      expect(env.capabilities).to contain_exactly(:search, :summarize)
    end

    it "handles single capability" do
      env = described_class.for_child(context: {}, capabilities: :search)
      expect(env.capabilities).to contain_exactly(:search)
    end

    it "handles empty capabilities" do
      env = described_class.for_child(context: {})
      expect(env.capabilities).to be_empty
    end

    it "stores parent fiber" do
      fiber = Fiber.new { Fiber.yield }
      env = described_class.for_child(context: {}, parent_fiber: fiber)
      expect(env.parent_fiber).to eq(fiber)
    end
  end

  describe "#can?" do
    subject(:env) do
      described_class.for_child(context: {}, capabilities: %i[search read])
    end

    it "returns true for present capability as symbol" do
      expect(env.can?(:search)).to be true
    end

    it "returns true for present capability as string" do
      expect(env.can?("search")).to be true
    end

    it "returns false for absent capability" do
      expect(env.can?(:write)).to be false
    end
  end

  describe "#[]" do
    subject(:env) do
      described_class.standalone(context: { task: "research", depth: 3 })
    end

    it "returns value for existing key" do
      expect(env[:task]).to eq("research")
    end

    it "returns nil for missing key" do
      expect(env[:missing]).to be_nil
    end

    it "returns default value for missing key" do
      expect(env[:missing, default: "fallback"]).to eq("fallback")
    end

    it "returns value even when default provided" do
      expect(env[:task, default: "fallback"]).to eq("research")
    end
  end

  describe "#has?" do
    subject(:env) do
      described_class.standalone(context: { task: "research", nil_value: nil })
    end

    it "returns true for existing key" do
      expect(env.has?(:task)).to be true
    end

    it "returns true for existing key with nil value" do
      expect(env.has?(:nil_value)).to be true
    end

    it "returns false for missing key" do
      expect(env.has?(:missing)).to be false
    end
  end

  describe "#ask" do
    context "without parent fiber" do
      subject(:env) { described_class.standalone }

      it "raises EnvironmentError" do
        expect { env.ask("question?") }.to raise_error(
          Smolagents::Errors::EnvironmentError,
          "Cannot ask: no parent fiber"
        )
      end
    end

    context "with parent fiber" do
      it "yields SubAgentQuery to parent" do
        yielded_request = nil
        parent_fiber = Fiber.new do |_|
          loop do
            request = Fiber.yield
            yielded_request = request
            Fiber.yield(Smolagents::Types::ControlRequests::Response.respond(
                          request_id: request.id,
                          value: "answer"
                        ))
          end
        end
        parent_fiber.resume

        env = described_class.for_child(
          context: { agent_name: "researcher" },
          parent_fiber:
        )

        child_fiber = Fiber.new do
          env.ask("What should I do?", options: %w[a b])
        end

        request = child_fiber.resume
        expect(request).to be_a(Smolagents::Types::ControlRequests::SubAgentQuery)
        expect(request.agent_name).to eq("researcher")
        expect(request.query).to eq("What should I do?")
        expect(request.options).to eq(%w[a b])
      end

      it "returns response value" do
        response_value = nil
        parent_fiber = Fiber.new do |_|
          loop do
            request = Fiber.yield
            Fiber.yield(Smolagents::Types::ControlRequests::Response.respond(
                          request_id: request.id,
                          value: "the answer"
                        ))
          end
        end
        parent_fiber.resume

        env = described_class.for_child(
          context: { agent_name: "child" },
          parent_fiber:
        )

        child_fiber = Fiber.new do
          response_value = env.ask("question?")
          :done
        end

        request = child_fiber.resume
        response = Smolagents::Types::ControlRequests::Response.respond(
          request_id: request.id,
          value: "the answer"
        )
        child_fiber.resume(response)

        expect(response_value).to eq("the answer")
      end

      it "uses default agent_name when not in context" do
        parent_fiber = Fiber.new do |_|
          loop do
            request = Fiber.yield
            Fiber.yield(Smolagents::Types::ControlRequests::Response.respond(
                          request_id: request.id,
                          value: nil
                        ))
          end
        end
        parent_fiber.resume

        env = described_class.for_child(context: {}, parent_fiber:)

        child_fiber = Fiber.new { env.ask("question?") }
        request = child_fiber.resume

        expect(request.agent_name).to eq("child")
      end
    end
  end

  describe "module alias" do
    it "is aliased at top level" do
      expect(Smolagents::Environment).to eq(described_class)
    end
  end

  describe "Data.define behavior" do
    it "is immutable" do
      env = described_class.standalone(context: { key: "value" })
      expect(env).to be_frozen
    end

    it "supports pattern matching" do
      env = described_class.standalone(context: { task: "test" })
      case env
      in { context:, capabilities:, parent_fiber: }
        expect(context).to eq({ task: "test" })
        expect(capabilities).to be_a(Set)
        expect(parent_fiber).to be_nil
      end
    end
  end
end
