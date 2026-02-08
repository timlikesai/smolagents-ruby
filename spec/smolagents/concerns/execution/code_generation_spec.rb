RSpec.describe Smolagents::Concerns::CodeGeneration do
  before do
    stub_const("TestCodeGenerator", Class.new do
      include Smolagents::Concerns::CodeGeneration

      attr_accessor :model

      def initialize(model: nil)
        @model = model
      end

      def write_memory_to_messages
        [Smolagents::ChatMessage.user("Test task")]
      end
    end)
  end

  let(:mock_model) do
    instance_double(Smolagents::Models::Model)
  end

  let(:generator) do
    TestCodeGenerator.new(model: mock_model)
  end

  let(:action_step) do
    Smolagents::ActionStepBuilder.new(step_number: 0)
  end

  let(:response_message) do
    Smolagents::ChatMessage.assistant(
      "```ruby\nputs 'hello'\n```",
      tool_calls: nil,
      token_usage: Smolagents::Types::TokenUsage.new(input_tokens: 10, output_tokens: 5)
    )
  end

  describe "#generate_code_response" do
    before do
      allow(mock_model).to receive(:generate).and_return(response_message)
    end

    it "calls model.generate with memory messages" do
      generator.generate_code_response(action_step)

      expect(mock_model).to have_received(:generate)
        .with([Smolagents::ChatMessage.user("Test task")], stop_sequences: nil)
    end

    it "updates action_step with model_output_message" do
      generator.generate_code_response(action_step)

      expect(action_step.model_output_message).to eq(response_message)
    end

    it "updates action_step with token_usage" do
      generator.generate_code_response(action_step)

      expect(action_step.token_usage.input_tokens).to eq(10)
      expect(action_step.token_usage.output_tokens).to eq(5)
    end

    it "returns the response" do
      result = generator.generate_code_response(action_step)

      expect(result).to eq(response_message)
    end
  end

  describe "context compression before generation" do
    before do
      allow(mock_model).to receive(:generate).and_return(response_message)
    end

    it "skips compression when memory does not support it" do
      generator.generate_code_response(action_step)

      expect(mock_model).to have_received(:generate).once
    end

    context "when memory supports compression" do
      before do
        stub_const("CompressibleGenerator", Class.new do
          include Smolagents::Events::Emitter
          include Smolagents::Events::Consumer
          include Smolagents::Concerns::CodeGeneration

          attr_accessor :model, :memory

          def write_memory_to_messages
            [Smolagents::ChatMessage.user("Test task")]
          end
        end)
      end

      let(:summary) do
        Smolagents::Types::SummaryStep.create(
          summary: "compressed", original_step_range: 0..2,
          original_step_count: 3, tokens_saved: 500
        )
      end

      let(:memory) do
        double(:agent_memory,
               compress_if_needed!: summary,
               token_usage_percent: 0.45)
      end

      let(:event_queue) { Thread::Queue.new }

      let(:compressible) do
        CompressibleGenerator.new.tap do |g|
          g.model = mock_model
          g.memory = memory
          g.connect_to(event_queue)
        end
      end

      def drain_events(queue)
        events = []
        events << queue.pop until queue.empty?
        events
      end

      it "calls compress_if_needed! before model.generate" do
        compressible.generate_code_response(action_step)

        expect(memory).to have_received(:compress_if_needed!).with(model: mock_model)
        expect(mock_model).to have_received(:generate)
      end

      it "emits context_compressed event on successful compression" do
        compressible.generate_code_response(action_step)

        events = drain_events(event_queue)
        compressed = events.select { |e| e.is_a?(Smolagents::Events::ContextCompressed) }
        expect(compressed.size).to eq(1)
        expect(compressed.first.steps_compressed).to eq(3)
        expect(compressed.first.tokens_saved).to eq(500)
        expect(compressed.first.new_usage_percent).to eq(0.45)
      end

      it "does not emit event when compression returns nil" do
        allow(memory).to receive(:compress_if_needed!).and_return(nil)

        compressible.generate_code_response(action_step)

        events = drain_events(event_queue)
        compressed = events.select { |e| e.is_a?(Smolagents::Events::ContextCompressed) }
        expect(compressed).to be_empty
      end
    end
  end

  describe "context window pre-generation check" do
    before do
      stub_const("WindowCheckGenerator", Class.new do
        include Smolagents::Events::Emitter
        include Smolagents::Events::Consumer
        include Smolagents::Concerns::CodeGeneration

        attr_accessor :model

        def write_memory_to_messages
          [Smolagents::ChatMessage.user("a" * 2000)]
        end
      end)
    end

    let(:event_queue) { Thread::Queue.new }

    def drain_events(queue)
      events = []
      events << queue.pop until queue.empty?
      events
    end

    context "when model has context_window" do
      let(:model_with_window) do
        instance_double(Smolagents::Models::Model, context_window: 100).tap do |m|
          allow(m).to receive(:generate).and_return(response_message)
        end
      end

      let(:checker) do
        WindowCheckGenerator.new.tap do |g|
          g.model = model_with_window
          g.connect_to(event_queue)
        end
      end

      it "emits context_window_exceeded when estimated tokens exceed window" do
        checker.generate_code_response(action_step)

        events = drain_events(event_queue)
        exceeded = events.select { |e| e.is_a?(Smolagents::Events::ContextWindowExceeded) }
        expect(exceeded.size).to eq(1)
        expect(exceeded.first.estimated_tokens).to eq(500)
        expect(exceeded.first.context_window).to eq(100)
        expect(exceeded.first.overflow_percent).to eq(500.0)
      end

      it "still calls model.generate after emitting warning" do
        checker.generate_code_response(action_step)

        expect(model_with_window).to have_received(:generate)
      end
    end

    context "when model has no context_window" do
      before do
        allow(mock_model).to receive(:generate).and_return(response_message)
      end

      it "skips check when context_window is nil" do
        gen = WindowCheckGenerator.new.tap do |g|
          g.model = mock_model
          g.connect_to(event_queue)
        end

        gen.generate_code_response(action_step)

        events = drain_events(event_queue)
        exceeded = events.select { |e| e.is_a?(Smolagents::Events::ContextWindowExceeded) }
        expect(exceeded).to be_empty
      end
    end

    context "when estimated tokens are within window" do
      let(:large_window_model) do
        instance_double(Smolagents::Models::Model, context_window: 100_000).tap do |m|
          allow(m).to receive(:generate).and_return(response_message)
        end
      end

      it "does not emit event when within budget" do
        gen = WindowCheckGenerator.new.tap do |g|
          g.model = large_window_model
          g.connect_to(event_queue)
        end

        gen.generate_code_response(action_step)

        events = drain_events(event_queue)
        exceeded = events.select { |e| e.is_a?(Smolagents::Events::ContextWindowExceeded) }
        expect(exceeded).to be_empty
      end
    end
  end
end
