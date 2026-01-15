require "spec_helper"

RSpec.describe "Control flow events" do
  describe Smolagents::Events::ControlYielded do
    describe ".create" do
      it "creates event with user_input request type" do
        event = described_class.create(
          request_type: :user_input,
          request_id: "req-123",
          prompt: "Please enter your name:"
        )

        expect(event.request_type).to eq(:user_input)
        expect(event.request_id).to eq("req-123")
        expect(event.prompt).to eq("Please enter your name:")
        expect(event.user_input?).to be true
        expect(event.confirmation?).to be false
      end

      it "creates event with confirmation request type" do
        event = described_class.create(
          request_type: :confirmation,
          request_id: "req-456",
          prompt: "Are you sure you want to proceed?"
        )

        expect(event.confirmation?).to be true
        expect(event.user_input?).to be false
      end

      it "creates event with sub_agent_query request type" do
        event = described_class.create(
          request_type: :sub_agent_query,
          request_id: "req-789",
          prompt: "Delegating to researcher"
        )

        expect(event.sub_agent_query?).to be true
      end

      it "has unique id and timestamp" do
        event = described_class.create(
          request_type: :user_input,
          request_id: "req-123",
          prompt: "test"
        )

        expect(event.id).to be_a(String)
        expect(event.id.length).to eq(36)
        expect(event.created_at).to be_a(Time)
      end
    end
  end

  describe Smolagents::Events::ControlResumed do
    describe ".create" do
      it "creates event with approval response" do
        event = described_class.create(
          request_id: "req-123",
          approved: true
        )

        expect(event.request_id).to eq("req-123")
        expect(event.approved).to be true
        expect(event.value).to be_nil
      end

      it "creates event with user-provided value" do
        event = described_class.create(
          request_id: "req-123",
          approved: true,
          value: "Alice"
        )

        expect(event.value).to eq("Alice")
      end

      it "creates event with rejection" do
        event = described_class.create(
          request_id: "req-123",
          approved: false
        )

        expect(event.approved).to be false
      end

      it "has unique id and timestamp" do
        event = described_class.create(
          request_id: "req-123",
          approved: true
        )

        expect(event.id).to be_a(String)
        expect(event.created_at).to be_a(Time)
      end
    end
  end

  describe "event subscription via mappings" do
    it "resolves :control_yielded to ControlYielded class" do
      klass = Smolagents::Events::Mappings.resolve(:control_yielded)
      expect(klass).to eq(Smolagents::Events::ControlYielded)
    end

    it "resolves :control_resumed to ControlResumed class" do
      klass = Smolagents::Events::Mappings.resolve(:control_resumed)
      expect(klass).to eq(Smolagents::Events::ControlResumed)
    end

    it "includes control events in valid names" do
      names = Smolagents::Events::Mappings.names
      expect(names).to include(:control_yielded)
      expect(names).to include(:control_resumed)
    end
  end

  describe "Consumer event handling" do
    let(:consumer_class) do
      Class.new do
        include Smolagents::Events::Consumer
      end
    end

    let(:consumer) { consumer_class.new }

    it "registers handler for control_yielded by name" do
      consumer.on(:control_yielded) { |_e| }
      expect(consumer.event_handlers).to have_key(Smolagents::Events::ControlYielded)
    end

    it "registers handler for control_resumed by name" do
      consumer.on(:control_resumed) { |_e| }
      expect(consumer.event_handlers).to have_key(Smolagents::Events::ControlResumed)
    end

    it "dispatches ControlYielded to matching handler" do
      results = []
      consumer.on(:control_yielded) { |e| results << e.prompt }

      event = Smolagents::Events::ControlYielded.create(
        request_type: :user_input,
        request_id: "req-1",
        prompt: "Enter value:"
      )

      consumer.consume(event)

      expect(results).to eq(["Enter value:"])
    end

    it "dispatches ControlResumed to matching handler" do
      results = []
      consumer.on(:control_resumed) { |e| results << e.value }

      event = Smolagents::Events::ControlResumed.create(
        request_id: "req-1",
        approved: true,
        value: "test-value"
      )

      consumer.consume(event)

      expect(results).to eq(["test-value"])
    end
  end

  describe "pattern matching on control events" do
    it "matches ControlYielded with request_type" do
      event = Smolagents::Events::ControlYielded.create(
        request_type: :confirmation,
        request_id: "req-1",
        prompt: "Confirm?"
      )

      result = case event
               in Smolagents::Events::ControlYielded[request_type: :confirmation, prompt:]
                 "Got confirmation: #{prompt}"
               in Smolagents::Events::ControlYielded[request_type: :user_input]
                 "User input request"
               else
                 "Unknown"
               end

      expect(result).to eq("Got confirmation: Confirm?")
    end

    it "matches ControlResumed with approved flag" do
      event = Smolagents::Events::ControlResumed.create(
        request_id: "req-1",
        approved: false
      )

      result = case event
               in Smolagents::Events::ControlResumed[approved: true, value:]
                 "Approved: #{value}"
               in Smolagents::Events::ControlResumed[approved: false]
                 "Rejected"
               end

      expect(result).to eq("Rejected")
    end
  end

  describe "Emitter integration" do
    let(:queue) { Thread::Queue.new }

    let(:emitter_class) do
      Class.new do
        include Smolagents::Events::Emitter

        def name
          "control_test"
        end
      end
    end

    let(:emitter) { emitter_class.new.connect_to(queue) }

    it "emits ControlYielded event" do
      event = Smolagents::Events::ControlYielded.create(
        request_type: :user_input,
        request_id: "req-1",
        prompt: "Enter name:"
      )

      emitter.emit(event)

      expect(queue.size).to eq(1)
      expect(queue.pop).to eq(event)
    end

    it "emits ControlResumed event" do
      event = Smolagents::Events::ControlResumed.create(
        request_id: "req-1",
        approved: true,
        value: "Alice"
      )

      emitter.emit(event)

      expect(queue.size).to eq(1)
      expect(queue.pop).to eq(event)
    end
  end

  describe "EventHandlers integration" do
    let(:builder_class) do
      Class.new do
        include Smolagents::Builders::EventHandlers

        attr_reader :configuration

        def initialize
          @configuration = { handlers: [] }
        end

        def check_frozen! = nil

        def with_config(**kwargs)
          new_instance = self.class.new
          new_instance.instance_variable_set(:@configuration, @configuration.merge(kwargs))
          new_instance
        end
      end
    end

    it "provides on_control_yielded convenience method" do
      builder = builder_class.new
      expect(builder).to respond_to(:on_control_yielded)
    end

    it "provides on_control_resumed convenience method" do
      builder = builder_class.new
      expect(builder).to respond_to(:on_control_resumed)
    end

    it "on_control_yielded subscribes to :control_yielded event" do
      builder = builder_class.new
      result = builder.on_control_yielded { |e| e }

      expect(result.configuration[:handlers].last.first).to eq(:control_yielded)
    end

    it "on_control_resumed subscribes to :control_resumed event" do
      builder = builder_class.new
      result = builder.on_control_resumed { |e| e }

      expect(result.configuration[:handlers].last.first).to eq(:control_resumed)
    end
  end
end
