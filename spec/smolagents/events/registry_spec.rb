require "spec_helper"

RSpec.describe Smolagents::Events::Registry do
  describe ".register" do
    after { described_class::EVENTS.delete(:test_event) }

    it "registers an event definition" do
      described_class.register :test_event,
                               description: "A test event",
                               params: %i[foo bar],
                               param_descriptions: { foo: "First param", bar: "Second param" },
                               category: :testing

      expect(described_class.registered?(:test_event)).to be true
    end

    it "returns the event definition" do
      defn = described_class.register :test_event,
                                      description: "A test event",
                                      params: %i[foo],
                                      category: :testing

      expect(defn).to be_a(described_class::EventDefinition)
      expect(defn.name).to eq(:test_event)
    end
  end

  describe ".[]" do
    it "returns registered event definition" do
      defn = described_class[:step_complete]

      expect(defn).not_to be_nil
      expect(defn.name).to eq(:step_complete)
    end

    it "returns nil for unknown event" do
      expect(described_class[:nonexistent]).to be_nil
    end
  end

  describe ".all" do
    it "returns all registered event names" do
      events = described_class.all

      expect(events).to include(:step_complete)
      expect(events).to include(:tool_complete)
      expect(events).to include(:error)
    end

    it "returns symbols" do
      expect(described_class.all).to all(be_a(Symbol))
    end
  end

  describe ".definitions" do
    it "returns all event definitions" do
      definitions = described_class.definitions

      expect(definitions).to all(be_a(described_class::EventDefinition))
      expect(definitions.size).to eq(described_class.all.size)
    end
  end

  describe ".registered?" do
    it "returns true for registered events" do
      expect(described_class.registered?(:step_complete)).to be true
    end

    it "returns false for unknown events" do
      expect(described_class.registered?(:unknown_event)).to be false
    end
  end

  describe ".by_category" do
    it "returns events filtered by category" do
      lifecycle_events = described_class.by_category(:lifecycle)

      expect(lifecycle_events).to include(:step_complete)
      expect(lifecycle_events).to include(:task_complete)
    end

    it "returns empty array for unknown category" do
      expect(described_class.by_category(:nonexistent)).to be_empty
    end
  end

  describe ".categories" do
    it "returns all unique categories" do
      categories = described_class.categories

      expect(categories).to include(:lifecycle)
      expect(categories).to include(:tools)
      expect(categories).to include(:errors)
      expect(categories).to all(be_a(Symbol))
    end

    it "returns sorted categories" do
      categories = described_class.categories
      expect(categories).to eq(categories.sort)
    end
  end

  describe ".documentation" do
    it "generates markdown documentation" do
      docs = described_class.documentation

      expect(docs).to include("## step_complete")
      expect(docs).to include("Signature:")
      expect(docs).to include("Parameters:")
    end

    it "includes examples when present" do
      docs = described_class.documentation

      expect(docs).to include("Example:")
      expect(docs).to include("agent.on(:step_complete)")
    end
  end

  describe ".for_builder" do
    it "returns agent-relevant events for :agent" do
      events = described_class.for_builder(:agent)

      expect(events).to include(:step_complete)
      expect(events).to include(:tool_complete)
      expect(events).to include(:error)
      expect(events).not_to include(:agent_launch) # team event
    end

    it "returns team-relevant events for :team" do
      events = described_class.for_builder(:team)

      expect(events).to include(:agent_launch)
      expect(events).to include(:agent_complete)
      expect(events).to include(:error)
      expect(events).not_to include(:step_complete) # agent event
    end

    it "returns model-relevant events for :model" do
      events = described_class.for_builder(:model)

      expect(events).to include(:retry)
      expect(events).to include(:failover)
      expect(events).to include(:recovery)
    end

    it "returns all events for unknown builder type" do
      expect(described_class.for_builder(:unknown)).to eq(described_class.all)
    end
  end

  describe Smolagents::Events::Registry::EventDefinition do
    let(:definition) do
      described_class.new(
        name: :test_event,
        description: "A test event",
        params: %i[foo bar],
        param_descriptions: { foo: "First param", bar: "Second param" },
        example: "agent.on(:test_event) { |foo, bar| puts foo }",
        category: :testing
      )
    end

    describe "#signature" do
      it "generates callback signature" do
        expect(definition.signature).to eq("on(:test_event) { |foo, bar| ... }")
      end
    end

    describe "#to_h" do
      it "converts to hash" do
        hash = definition.to_h

        expect(hash[:name]).to eq(:test_event)
        expect(hash[:description]).to eq("A test event")
        expect(hash[:params]).to eq(%i[foo bar])
        expect(hash[:signature]).to eq("on(:test_event) { |foo, bar| ... }")
        expect(hash[:example]).to include("agent.on(:test_event)")
        expect(hash[:category]).to eq(:testing)
      end
    end

    describe "#deconstruct_keys" do
      it "supports pattern matching" do
        case definition
        in { name: :test_event, params: }
          expect(params).to eq(%i[foo bar])
        else
          raise "Pattern should have matched"
        end
      end
    end
  end

  describe "built-in event registrations" do
    it "registers step_complete with correct params" do
      defn = described_class[:step_complete]

      expect(defn.params).to eq(%i[step context])
      expect(defn.category).to eq(:lifecycle)
    end

    it "registers tool_complete with correct params" do
      defn = described_class[:tool_complete]

      expect(defn.params).to eq(%i[tool_call result])
      expect(defn.category).to eq(:tools)
    end

    it "registers error with correct params" do
      defn = described_class[:error]

      expect(defn.params).to eq(%i[error_class error_message context recoverable])
      expect(defn.category).to eq(:errors)
    end

    it "registers agent lifecycle events" do
      %i[agent_launch agent_progress agent_complete].each do |name|
        expect(described_class.registered?(name)).to be true
        expect(described_class[name].category).to eq(:subagents)
      end
    end

    it "registers resilience events" do
      %i[retry failover recovery].each do |name|
        expect(described_class.registered?(name)).to be true
        expect(described_class[name].category).to eq(:resilience)
      end
    end

    it "registers control flow events" do
      %i[control_yielded control_resumed].each do |name|
        expect(described_class.registered?(name)).to be true
        expect(described_class[name].category).to eq(:control)
      end
    end

    it "registers metacognition events" do
      %i[evaluation_complete refinement_complete goal_drift repetition_detected].each do |name|
        expect(described_class.registered?(name)).to be true
        expect(described_class[name].category).to eq(:metacognition)
      end
    end
  end
end

# rubocop:disable RSpec/DescribeClass -- tests module-level DSL, not a class
RSpec.describe "Smolagents event DSL methods" do
  describe "Smolagents.events" do
    it "returns all event names" do
      events = Smolagents.events

      expect(events).to be_an(Array)
      expect(events).to include(:step_complete)
    end
  end

  describe "Smolagents.event" do
    it "returns event definition" do
      defn = Smolagents.event(:step_complete)

      expect(defn).to be_a(Smolagents::Events::Registry::EventDefinition)
      expect(defn.name).to eq(:step_complete)
    end

    it "returns nil for unknown event" do
      expect(Smolagents.event(:unknown)).to be_nil
    end
  end

  describe "Smolagents.event_docs" do
    it "returns documentation string" do
      docs = Smolagents.event_docs

      expect(docs).to be_a(String)
      expect(docs).to include("step_complete")
      expect(docs).to include("Signature:")
    end
  end
end
# rubocop:enable RSpec/DescribeClass
