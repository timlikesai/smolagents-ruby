RSpec.describe Smolagents::Events::DSL do
  let(:test_module) do
    Module.new do
      extend Smolagents::Events::DSL
    end
  end

  describe ".define_event" do
    it "creates an event class" do
      test_module.define_event :TestEvent, fields: %i[name value]

      expect(test_module.const_defined?(:TestEvent)).to be true
      expect(test_module::TestEvent).to be_a(Class)
    end

    it "event class responds to create" do
      test_module.define_event :SimpleEvent, fields: %i[data]

      expect(test_module::SimpleEvent).to respond_to(:create)
    end

    it "create generates unique IDs" do
      test_module.define_event :IdEvent, fields: %i[content]

      event1 = test_module::IdEvent.create(content: "test1")
      event2 = test_module::IdEvent.create(content: "test2")

      expect(event1.id).not_to eq(event2.id)
    end

    it "create sets created_at timestamp" do
      test_module.define_event :TimeEvent, fields: %i[data]

      event = test_module::TimeEvent.create(data: "test")

      expect(event.created_at).to be_a(Time)
    end

    it "includes standard fields (id, sequence, created_at)" do
      test_module.define_event :FieldEvent, fields: %i[name]

      event = test_module::FieldEvent.create(name: "test")

      expect(event).to respond_to(:id)
      expect(event).to respond_to(:sequence)
      expect(event).to respond_to(:created_at)
      expect(event).to respond_to(:name)
    end

    it "event instance is frozen" do
      test_module.define_event :FrozenEvent, fields: %i[value]

      event = test_module::FrozenEvent.create(value: 42)

      expect(event).to be_frozen
    end
  end

  describe "predicates" do
    it "creates predicate methods from predicates hash" do
      test_module.define_event :OutcomeEvent,
                               fields: %i[outcome],
                               predicates: { success: :success, error: :error }

      event = test_module::OutcomeEvent.create(outcome: :success)

      expect(event).to respond_to(:success?)
      expect(event).to respond_to(:error?)
    end

    it "returns true for matching predicate" do
      test_module.define_event :StatusEvent,
                               fields: %i[status],
                               predicates: { active: :active, inactive: :inactive },
                               predicate_field: :status

      event = test_module::StatusEvent.create(status: :active)

      expect(event.active?).to be true
      expect(event.inactive?).to be false
    end

    it "returns false for non-matching predicate" do
      test_module.define_event :ResultEvent,
                               fields: %i[result],
                               predicates: { ok: :ok, fail: :fail },
                               predicate_field: :result

      event = test_module::ResultEvent.create(result: :fail)

      expect(event.ok?).to be false
      expect(event.fail?).to be true
    end

    it "uses default predicate_field :outcome" do
      test_module.define_event :SimplePredicateEvent,
                               fields: %i[outcome],
                               predicates: { pass: :pass }

      event = test_module::SimplePredicateEvent.create(outcome: :pass)

      expect(event.pass?).to be true
    end

    it "supports custom predicate_field" do
      test_module.define_event :CustomFieldEvent,
                               fields: %i[type data],
                               predicates: { user_input: :user_input },
                               predicate_field: :type

      event = test_module::CustomFieldEvent.create(type: :user_input, data: "test")

      expect(event.user_input?).to be true
    end
  end

  describe "field freezing" do
    it "freezes specified fields" do
      test_module.define_event :FreezeEvent,
                               fields: %i[args],
                               freeze: [:args]

      mutable_array = [1, 2, 3]
      event = test_module::FreezeEvent.create(args: mutable_array)

      expect(event.args).to be_frozen
    end

    it "does not freeze unspecified fields" do
      test_module.define_event :PartialFreezeEvent,
                               fields: %i[frozen mutable],
                               freeze: [:frozen]

      event = test_module::PartialFreezeEvent.create(
        frozen: [1, 2],
        mutable: [3, 4]
      )

      expect(event.frozen).to be_frozen
      expect(event.mutable).not_to be_frozen
    end

    it "handles nil values when freezing" do
      test_module.define_event :NilFreezeEvent,
                               fields: %i[data],
                               freeze: [:data]

      event = test_module::NilFreezeEvent.create(data: nil)

      expect(event.data).to be_nil
    end
  end

  describe "error extraction" do
    it "extracts error class and message when from_error: true" do
      test_module.define_event :ErrorEvent,
                               fields: %i[error_class error_message context],
                               from_error: true

      error = StandardError.new("Test error")
      event = test_module::ErrorEvent.create(error:, context: {})

      expect(event.error_class).to eq("StandardError")
      expect(event.error_message).to eq("Test error")
    end

    it "handles custom error classes" do
      class CustomError < StandardError; end

      test_module.define_event :CustomErrorEvent,
                               fields: %i[error_class error_message],
                               from_error: true

      error = CustomError.new("Custom message")
      event = test_module::CustomErrorEvent.create(error:)

      expect(event.error_class).to eq("CustomError")
      expect(event.error_message).to eq("Custom message")
    end

    it "ignores error extraction when from_error: false" do
      test_module.define_event :NoErrorEvent,
                               fields: %i[data],
                               from_error: false

      event = test_module::NoErrorEvent.create(data: "test")

      expect(event.respond_to?(:error_class)).to be false
    end
  end

  describe "defaults" do
    it "applies default values from defaults hash" do
      test_module.define_event :DefaultEvent,
                               fields: %i[status context],
                               defaults: { context: {}, status: :pending }

      event = test_module::DefaultEvent.create

      expect(event.context).to eq({})
      expect(event.status).to eq(:pending)
    end

    it "allows overriding defaults" do
      test_module.define_event :OverrideDefaultEvent,
                               fields: %i[count],
                               defaults: { count: 0 }

      event = test_module::OverrideDefaultEvent.create(count: 5)

      expect(event.count).to eq(5)
    end

    it "only applies defaults for missing keys" do
      test_module.define_event :SelectiveDefaultEvent,
                               fields: %i[a b],
                               defaults: { a: 1, b: 2 }

      event = test_module::SelectiveDefaultEvent.create(a: 10)

      expect(event.a).to eq(10)
      expect(event.b).to eq(2)
    end
  end

  describe "event_config" do
    it "attaches event_config to event class" do
      test_module.define_event :ConfigEvent,
                               fields: %i[data],
                               predicates: { ok: :ok },
                               freeze: [:data]

      config = test_module::ConfigEvent.event_config

      expect(config).to be_a(Smolagents::Events::EventConfig)
      expect(config.predicates).to have_key(:ok)
      expect(config.freeze_fields).to include(:data)
    end
  end

  describe "EventConfig" do
    it "is a Data.define class" do
      expect(Smolagents::Events::EventConfig).to be_a(Class)
    end

    it "stores predicates" do
      config = Smolagents::Events::EventConfig.new(
        predicates: { ok: :ok },
        predicate_field: :outcome,
        freeze_fields: [],
        from_error: false,
        defaults: {},
        category: nil,
        description: nil
      )

      expect(config.predicates).to eq({ ok: :ok })
    end
  end

  describe "EventBuilder" do
    it "builds event class with create method" do
      fields = %i[status data created_at id]
      config = Smolagents::Events::EventConfig.new(
        predicates: {},
        predicate_field: :status,
        freeze_fields: [],
        from_error: false,
        defaults: {},
        category: nil,
        description: nil
      )

      event_class = Smolagents::Events::EventBuilder.build(fields, config)

      expect(event_class).to respond_to(:create)
    end
  end

  describe "integration test" do
    it "creates complete event with all features" do
      test_module.define_event :CompleteEvent,
                               fields: %i[status message items],
                               predicates: { success: :success, failure: :failure },
                               predicate_field: :status,
                               freeze: [:items],
                               defaults: { items: [] }
      event = test_module::CompleteEvent.create(
        status: :success,
        message: "Operation completed"
      )

      expect(event).to be_frozen
      expect(event.id).not_to be_nil
      expect(event.sequence).to be_a(Integer)
      expect(event.created_at).to be_a(Time)
      expect(event.status).to eq(:success)
      expect(event.message).to eq("Operation completed")
      expect(event.items).to eq([])
      expect(event.success?).to be true
      expect(event.failure?).to be false
    end
  end

  describe "sequence numbers" do
    before do
      # Reset sequence counter for deterministic tests
      Smolagents::Events::CreateFactory.reset_sequence!
    end

    it "assigns monotonically increasing sequence numbers" do
      test_module.define_event :SeqEvent, fields: %i[data]

      event1 = test_module::SeqEvent.create(data: "first")
      event2 = test_module::SeqEvent.create(data: "second")
      event3 = test_module::SeqEvent.create(data: "third")

      expect(event1.sequence).to eq(1)
      expect(event2.sequence).to eq(2)
      expect(event3.sequence).to eq(3)
    end

    it "maintains order across different event types" do
      test_module.define_event :TypeA, fields: %i[value]
      test_module.define_event :TypeB, fields: %i[value]

      a1 = test_module::TypeA.create(value: "a1")
      b1 = test_module::TypeB.create(value: "b1")
      a2 = test_module::TypeA.create(value: "a2")

      expect(a1.sequence).to be < b1.sequence
      expect(b1.sequence).to be < a2.sequence
    end

    it "is thread-safe under concurrent creation" do
      test_module.define_event :ConcurrentEvent, fields: %i[thread_id]

      events = []
      mutex = Mutex.new

      threads = Array.new(10) do |i|
        Thread.new do
          5.times do
            event = test_module::ConcurrentEvent.create(thread_id: i)
            mutex.synchronize { events << event }
          end
        end
      end

      threads.each(&:join)

      # All sequence numbers should be unique
      sequences = events.map(&:sequence)
      expect(sequences.uniq.size).to eq(50)

      # Sequence numbers should be consecutive (1..50)
      expect(sequences.sort).to eq((1..50).to_a)
    end
  end

  describe "CreateFactory" do
    describe ".reset_sequence!" do
      it "resets the sequence counter to zero" do
        test_module.define_event :ResetEvent, fields: %i[data]

        test_module::ResetEvent.create(data: "before")
        test_module::ResetEvent.create(data: "before")

        Smolagents::Events::CreateFactory.reset_sequence!

        event = test_module::ResetEvent.create(data: "after")
        expect(event.sequence).to eq(1)
      end
    end

    describe ".current_sequence" do
      it "returns current counter value" do
        Smolagents::Events::CreateFactory.reset_sequence!
        test_module.define_event :CurrentEvent, fields: %i[data]

        expect(Smolagents::Events::CreateFactory.current_sequence).to eq(0)

        test_module::CurrentEvent.create(data: "test")
        expect(Smolagents::Events::CreateFactory.current_sequence).to eq(1)

        test_module::CurrentEvent.create(data: "test")
        expect(Smolagents::Events::CreateFactory.current_sequence).to eq(2)
      end
    end
  end
end
