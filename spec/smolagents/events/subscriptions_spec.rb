require "spec_helper"

RSpec.describe Smolagents::Events::Subscriptions do
  # Test class that includes the Subscriptions module
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Subscriptions

      attr_reader :configuration

      def initialize
        @configuration = { handlers: [] }
        @frozen = false
      end

      def check_frozen!
        raise FrozenError, "Builder is frozen" if @frozen
      end

      def with_config(**kwargs)
        new_instance = self.class.new
        new_instance.instance_variable_set(:@configuration, @configuration.merge(kwargs))
        new_instance
      end

      def freeze!
        @frozen = true
        self
      end
    end
  end

  describe "ClassMethods" do
    describe ".configure_events" do
      it "configures the events storage key" do
        test_class.configure_events(key: :callbacks, format: :hash)

        expect(test_class.events_key).to eq(:callbacks)
        expect(test_class.events_format).to eq(:hash)
      end

      it "defaults to :handlers key and :tuple format" do
        expect(test_class.events_key).to eq(:handlers)
        expect(test_class.events_format).to eq(:tuple)
      end
    end

    describe ".define_handler" do
      it "defines a convenience method for event subscription" do
        test_class.define_handler :step, maps_to: :step_complete

        instance = test_class.new
        expect(instance).to respond_to(:on_step)
      end

      it "uses the handler name as event type when maps_to is not specified" do
        test_class.define_handler :error

        instance = test_class.new
        result = instance.on_error { |e| e }

        expect(result.configuration[:handlers].last.first).to eq(:error)
      end

      it "maps to the specified event type" do
        test_class.define_handler :step, maps_to: :step_complete

        instance = test_class.new
        result = instance.on_step { |e| e }

        expect(result.configuration[:handlers].last.first).to eq(:step_complete)
      end
    end
  end

  describe "#on" do
    it "adds a handler to configuration" do
      instance = test_class.new
      handler = proc { |e| e }

      result = instance.on(:step_complete, &handler)

      expect(result.configuration[:handlers].size).to eq(1)
      expect(result.configuration[:handlers].first).to eq([:step_complete, handler])
    end

    it "returns a new instance (immutable)" do
      instance = test_class.new
      result = instance.on(:step_complete) { |e| e }

      expect(result).not_to eq(instance)
      expect(instance.configuration[:handlers]).to be_empty
    end

    it "raises FrozenError when frozen" do
      instance = test_class.new.freeze!

      expect { instance.on(:step_complete) { |e| e } }.to raise_error(FrozenError)
    end

    it "supports chaining multiple handlers" do
      instance = test_class.new

      result = instance
               .on(:step_complete) { |e| e }
               .on(:error) { |e| e }
               .on(:task_complete) { |e| e }

      expect(result.configuration[:handlers].size).to eq(3)
    end
  end

  describe "with :hash format" do
    before do
      test_class.configure_events(key: :callbacks, format: :hash)
    end

    let(:hash_configured_class) do
      klass = Class.new do
        include Smolagents::Events::Subscriptions

        attr_reader :configuration

        def initialize
          @configuration = { callbacks: [] }
        end

        def check_frozen! = nil

        def with_config(**kwargs)
          new_instance = self.class.new
          new_instance.instance_variable_set(:@configuration, @configuration.merge(kwargs))
          new_instance
        end
      end
      klass.configure_events(key: :callbacks, format: :hash)
      klass
    end

    it "stores handlers as hashes" do
      instance = hash_configured_class.new
      handler = proc { |e| e }

      result = instance.on(:failover, &handler)

      expect(result.configuration[:callbacks].first).to eq({ type: :failover, handler: })
    end
  end
end
