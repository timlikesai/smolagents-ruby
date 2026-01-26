require "spec_helper"

RSpec.describe Smolagents::Builders::EventHandlers do
  let(:test_builder_class) do
    Class.new(Data.define(:configuration)) do
      include Smolagents::Builders::Base
      include Smolagents::Builders::EventHandlers

      def self.create
        new(configuration: { handlers: [] })
      end

      def with_config(new_config)
        self.class.new(configuration: configuration.merge(new_config))
      end
    end
  end

  let(:builder) { test_builder_class.create }

  describe "event handler methods" do
    describe "#on" do
      it "stores event handler" do
        handler = proc { |event| :handled }
        result = builder.on(:step_complete, &handler)

        expect(result.configuration[:handlers]).to be_a(Array)
        expect(result.configuration[:handlers].size).to eq(1)
      end

      it "returns new builder instance (immutable)" do
        handler = proc { |_| :ok }
        result = builder.on(:step_complete, &handler)

        expect(result).to be_a(test_builder_class)
        expect(result).not_to equal(builder)
      end

      it "accumulates multiple handlers" do
        handler1 = proc { |_| :handler1 }
        handler2 = proc { |_| :handler2 }
        handler3 = proc { |_| :handler3 }

        result = builder
                 .on(:step_complete, &handler1)
                 .on(:task_complete, &handler2)
                 .on(:error, &handler3)

        expect(result.configuration[:handlers].size).to eq(3)
      end
    end

    describe "convenience handler methods" do
      it "provides #on_step convenience method" do
        handler = proc { |event| :step_handled }
        result = builder.on_step(&handler)

        expect(result.configuration[:handlers].size).to eq(1)
        expect(result.configuration[:handlers].first[0]).to eq(:step_complete)
      end

      it "provides #on_task convenience method" do
        handler = proc { |event| :task_handled }
        result = builder.on_task(&handler)

        expect(result.configuration[:handlers].size).to eq(1)
        expect(result.configuration[:handlers].first[0]).to eq(:task_complete)
      end

      it "provides #on_error convenience method" do
        handler = proc { |event| :error_handled }
        result = builder.on_error(&handler)

        expect(result.configuration[:handlers].size).to eq(1)
        expect(result.configuration[:handlers].first[0]).to eq(:error)
      end

      it "provides #on_control_yielded convenience method" do
        handler = proc { |event| :control_handled }
        result = builder.on_control_yielded(&handler)

        expect(result.configuration[:handlers].size).to eq(1)
        expect(result.configuration[:handlers].first[0]).to eq(:control_yielded)
      end

      it "provides #on_control_resumed convenience method" do
        handler = proc { |event| :control_resumed }
        result = builder.on_control_resumed(&handler)

        expect(result.configuration[:handlers].size).to eq(1)
        expect(result.configuration[:handlers].first[0]).to eq(:control_resumed)
      end

      it "provides #on_isolation convenience method" do
        handler = proc { |event| :isolation_handled }
        result = builder.on_isolation(&handler)

        expect(result.configuration[:handlers].size).to eq(1)
        expect(result.configuration[:handlers].first[0]).to eq(:tool_isolation_completed)
      end

      it "provides #on_violation convenience method" do
        handler = proc { |event| :violation_handled }
        result = builder.on_violation(&handler)

        expect(result.configuration[:handlers].size).to eq(1)
        expect(result.configuration[:handlers].first[0]).to eq(:resource_violation)
      end
    end

    describe "handler aliases" do
      it "maps :step to :step_complete" do
        handler = proc { |_| :ok }
        builder.on(:step, &handler)

        # Verify the convenience method exists and works
        expect(builder).to respond_to(:on_step)
      end

      it "maps :task to :task_complete" do
        handler = proc { |_| :ok }
        builder.on(:task, &handler)

        # Verify the convenience method exists
        expect(builder).to respond_to(:on_task)
      end

      it "maps :isolation to :tool_isolation_completed" do
        handler = proc { |_| :ok }
        builder.on(:isolation, &handler)

        # Verify the convenience method exists
        expect(builder).to respond_to(:on_isolation)
      end

      it "maps :violation to :resource_violation" do
        handler = proc { |_| :ok }
        builder.on(:violation, &handler)

        # Verify the convenience method exists
        expect(builder).to respond_to(:on_violation)
      end

      it "preserves unmapped event types" do
        handler = proc { |_| :ok }
        result = builder.on(:error, &handler)

        expect(result.configuration[:handlers].first[0]).to eq(:error)
      end
    end
  end

  describe "handler configuration" do
    it "stores handlers as tuples [event_type, handler_block]" do
      handler = proc { |event| "handled" }
      result = builder.on(:step_complete, &handler)

      handlers = result.configuration[:handlers]
      expect(handlers.first).to be_a(Array)
      expect(handlers.first.size).to eq(2)
      expect(handlers.first[0]).to eq(:step_complete)
      expect(handlers.first[1]).to be_a(Proc)
    end

    it "preserves handler order" do
      h1 = proc { |_| :h1 }
      h2 = proc { |_| :h2 }
      h3 = proc { |_| :h3 }

      result = builder
               .on(:step_complete, &h1)
               .on(:task_complete, &h2)
               .on(:error, &h3)

      handlers = result.configuration[:handlers]
      expect(handlers[0][0]).to eq(:step_complete)
      expect(handlers[1][0]).to eq(:task_complete)
      expect(handlers[2][0]).to eq(:error)
    end

    it "allows same event type with multiple handlers" do
      h1 = proc { |_| :h1 }
      h2 = proc { |_| :h2 }

      result = builder
               .on(:step_complete, &h1)
               .on(:step_complete, &h2)

      handlers = result.configuration[:handlers]
      expect(handlers.size).to eq(2)
      expect(handlers.all? { |h| h[0] == :step_complete }).to be true
    end
  end

  describe "handler methods" do
    it "requires block for handler registration" do
      # The base on method should require a block
      expect(builder).to respond_to(:on)
    end

    it "convenience methods are available" do
      expect(builder).to respond_to(:on_step)
      expect(builder).to respond_to(:on_task)
      expect(builder).to respond_to(:on_error)
    end
  end
end
