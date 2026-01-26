require "spec_helper"

RSpec.describe Smolagents::Security::SpawnViolation do
  describe ".depth_exceeded" do
    subject(:violation) { described_class.depth_exceeded(current: 3, max: 2) }

    it "sets type to :depth_exceeded" do
      expect(violation.type).to eq(:depth_exceeded)
    end

    it "stores current depth in detail" do
      expect(violation.detail[:current]).to eq(3)
    end

    it "stores max depth in detail" do
      expect(violation.detail[:max]).to eq(2)
    end

    it "freezes detail hash" do
      expect(violation.detail).to be_frozen
    end

    it "creates multiple violations independently" do
      v1 = described_class.depth_exceeded(current: 3, max: 2)
      v2 = described_class.depth_exceeded(current: 5, max: 4)
      expect(v1.detail[:current]).to eq(3)
      expect(v2.detail[:current]).to eq(5)
    end
  end

  describe ".unauthorized_tool" do
    subject(:violation) { described_class.unauthorized_tool(:database) }

    it "sets type to :unauthorized_tool" do
      expect(violation.type).to eq(:unauthorized_tool)
    end

    it "stores tool name in detail" do
      expect(violation.detail[:tool]).to eq(:database)
    end

    it "freezes detail hash" do
      expect(violation.detail).to be_frozen
    end

    it "handles string tool names" do
      v = described_class.unauthorized_tool("api_call")
      expect(v.detail[:tool]).to eq("api_call")
    end

    it "handles symbol tool names" do
      v = described_class.unauthorized_tool(:search)
      expect(v.detail[:tool]).to eq(:search)
    end
  end

  describe ".steps_exceeded" do
    subject(:violation) { described_class.steps_exceeded(requested: 50, max_per_agent: 30, remaining: 10) }

    it "sets type to :steps_exceeded" do
      expect(violation.type).to eq(:steps_exceeded)
    end

    it "stores requested steps in detail" do
      expect(violation.detail[:requested]).to eq(50)
    end

    it "stores max_per_agent in detail" do
      expect(violation.detail[:max_per_agent]).to eq(30)
    end

    it "stores remaining in detail" do
      expect(violation.detail[:remaining]).to eq(10)
    end

    it "freezes detail hash" do
      expect(violation.detail).to be_frozen
    end

    it "handles different numeric values" do
      v = described_class.steps_exceeded(requested: 100, max_per_agent: 50, remaining: 5)
      expect(v.detail[:requested]).to eq(100)
      expect(v.detail[:max_per_agent]).to eq(50)
      expect(v.detail[:remaining]).to eq(5)
    end

    it "handles zero remaining steps" do
      v = described_class.steps_exceeded(requested: 10, max_per_agent: 10, remaining: 0)
      expect(v.detail[:remaining]).to eq(0)
    end
  end

  describe "#to_s" do
    describe "for depth_exceeded" do
      it "formats depth_exceeded message" do
        violation = described_class.depth_exceeded(current: 3, max: 2)
        expect(violation.to_s).to eq("Depth limit exceeded: at depth 3, max is 2")
      end

      it "includes both current and max depth" do
        violation = described_class.depth_exceeded(current: 5, max: 3)
        message = violation.to_s
        expect(message).to include("5")
        expect(message).to include("3")
      end

      it "uses consistent wording" do
        violation = described_class.depth_exceeded(current: 1, max: 0)
        message = violation.to_s
        expect(message).to start_with("Depth limit exceeded:")
      end
    end

    describe "for unauthorized_tool" do
      it "formats unauthorized_tool message" do
        violation = described_class.unauthorized_tool(:database)
        expect(violation.to_s).to eq("Tool :database not allowed for sub-agents")
      end

      it "includes tool name" do
        violation = described_class.unauthorized_tool(:api_call)
        message = violation.to_s
        expect(message).to include("api_call")
      end

      it "prefixes tool name with colon" do
        violation = described_class.unauthorized_tool(:search)
        message = violation.to_s
        expect(message).to include(":search")
      end

      it "mentions sub-agents" do
        violation = described_class.unauthorized_tool(:secret_tool)
        message = violation.to_s
        expect(message).to include("sub-agents")
      end

      it "handles string tool names" do
        violation = described_class.unauthorized_tool("fetch_data")
        message = violation.to_s
        expect(message).to include("fetch_data")
      end
    end

    describe "for steps_exceeded" do
      it "formats steps_exceeded message" do
        violation = described_class.steps_exceeded(requested: 50, max_per_agent: 30, remaining: 10)
        message = violation.to_s
        expect(message).to include("Steps exceeded:")
        expect(message).to include("50")
        expect(message).to include("30")
        expect(message).to include("10")
      end

      it "includes all three values" do
        violation = described_class.steps_exceeded(requested: 100, max_per_agent: 50, remaining: 5)
        message = violation.to_s
        expect(message).to include("100")
        expect(message).to include("50")
        expect(message).to include("5")
      end

      it "mentions requested, max, and remaining" do
        violation = described_class.steps_exceeded(requested: 25, max_per_agent: 15, remaining: 8)
        message = violation.to_s
        expect(message).to include("requested")
        expect(message).to include("max per agent")
        expect(message).to include("remaining budget")
      end
    end
  end

  describe "pattern matching with deconstruct_keys" do
    it "supports pattern matching for depth_exceeded" do
      violation = described_class.depth_exceeded(current: 3, max: 2)
      matched = case violation
                in { type: :depth_exceeded, detail: { current: 3 } }
                  true
                else
                  false
                end
      expect(matched).to be true
    end

    it "supports pattern matching for unauthorized_tool" do
      violation = described_class.unauthorized_tool(:search)
      matched = case violation
                in { type: :unauthorized_tool, detail: { tool: :search } }
                  true
                else
                  false
                end
      expect(matched).to be true
    end

    it "supports pattern matching for steps_exceeded" do
      violation = described_class.steps_exceeded(requested: 50, max_per_agent: 30, remaining: 10)
      matched = case violation
                in { type: :steps_exceeded, detail: { requested: 50 } }
                  true
                else
                  false
                end
      expect(matched).to be true
    end

    it "deconstruct_keys returns type and detail" do
      violation = described_class.depth_exceeded(current: 2, max: 1)
      keys = violation.deconstruct_keys(nil)
      expect(keys).to have_key(:type)
      expect(keys).to have_key(:detail)
    end
  end

  describe "immutability" do
    it "is immutable (Data.define)" do
      violation = described_class.depth_exceeded(current: 3, max: 2)
      expect { violation.type = :other }.to raise_error(NoMethodError)
    end

    it "prevents modification of detail hash" do
      violation = described_class.unauthorized_tool(:search)
      expect { violation.detail[:tool] = :other }.to raise_error(FrozenError)
    end
  end

  describe "multiple violations of different types" do
    it "creates independent violations" do
      v1 = described_class.depth_exceeded(current: 3, max: 2)
      v2 = described_class.unauthorized_tool(:database)
      v3 = described_class.steps_exceeded(requested: 50, max_per_agent: 30, remaining: 10)

      expect(v1.type).to eq(:depth_exceeded)
      expect(v2.type).to eq(:unauthorized_tool)
      expect(v3.type).to eq(:steps_exceeded)
    end

    it "produces different string representations" do
      v1 = described_class.depth_exceeded(current: 3, max: 2)
      v2 = described_class.unauthorized_tool(:search)
      v3 = described_class.steps_exceeded(requested: 50, max_per_agent: 30, remaining: 10)

      expect(v1.to_s).not_to eq(v2.to_s)
      expect(v2.to_s).not_to eq(v3.to_s)
      expect(v1.to_s).not_to eq(v3.to_s)
    end
  end
end
