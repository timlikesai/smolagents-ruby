require "smolagents"

RSpec.describe Smolagents::Concerns::ReActLoop::Execution::Streaming do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::ReActLoop::Execution::Streaming

      attr_accessor :model, :ctx

      # Make private methods public for testing
      public :token_streaming?, :enable_token_streaming!, :disable_token_streaming!,
             :generate_with_streaming, :streamable?, :stream_and_accumulate,
             :emit_token_if_present
    end
  end

  let(:event_queue) { Thread::Queue.new }

  let(:model) { double("Model") }

  let(:instance) do
    obj = test_class.new
    obj.model = model
    obj.ctx = nil
    obj.connect_to(event_queue)
    obj
  end

  let(:messages) { [double("message")] }
  let(:tools) { [double("tool")] }

  def drain_events
    event_queue.close
    events = []
    while (event = event_queue.pop)
      events << event
    end
    events
  end

  describe "#token_streaming?" do
    it "returns false by default" do
      expect(instance.token_streaming?).to be false
    end

    it "returns true after enable_token_streaming!" do
      instance.enable_token_streaming!
      expect(instance.token_streaming?).to be true
    end
  end

  describe "#enable_token_streaming! and #disable_token_streaming!" do
    it "enables streaming" do
      instance.enable_token_streaming!
      expect(instance.token_streaming?).to be true
    end

    it "disables streaming" do
      instance.enable_token_streaming!
      instance.disable_token_streaming!
      expect(instance.token_streaming?).to be false
    end
  end

  describe "#generate_with_streaming" do
    context "when streaming is disabled" do
      it "falls through to model.generate" do
        allow(model).to receive(:generate).and_return("response")

        result = instance.generate_with_streaming(messages, tools:)

        expect(result).to eq("response")
        expect(model).to have_received(:generate).with(messages, tools:)
      end
    end

    context "when model does not support generate_stream" do
      it "falls through to model.generate" do
        instance.enable_token_streaming!
        allow(model).to receive(:respond_to?).with(:generate_stream).and_return(false)
        allow(model).to receive(:generate).and_return("response")

        result = instance.generate_with_streaming(messages, tools:)

        expect(result).to eq("response")
        expect(model).to have_received(:generate)
      end
    end

    context "when streaming enabled and model supports it" do
      before do
        instance.enable_token_streaming!
        allow(model).to receive(:respond_to?).with(:generate_stream).and_return(true)
      end

      it "calls generate_stream on the model" do
        chunks = [double(content: "hello"), double(content: " world")]
        allow(model).to receive(:generate_stream).and_return(chunks)

        instance.generate_with_streaming(messages, tools:)

        expect(model).to have_received(:generate_stream).with(messages, tools:)
      end

      it "accumulates tokens from chunks" do
        chunks = [double(content: "hello"), double(content: " world")]
        allow(model).to receive(:generate_stream).and_return(chunks)

        result = instance.generate_with_streaming(messages, tools:)

        expect(result).to eq("hello world")
      end

      it "emits model_token_generated events per chunk" do
        chunks = [double(content: "a"), double(content: "b")]
        allow(model).to receive(:generate_stream).and_return(chunks)

        instance.generate_with_streaming(messages, tools:)
        events = drain_events

        token_events = events.select { |e| e.is_a?(Smolagents::Events::ModelTokenGenerated) }
        expect(token_events.size).to eq(2)
        expect(token_events.map(&:token)).to eq(%w[a b])
      end

      it "skips nil tokens" do
        chunks = [double(content: nil), double(content: "ok")]
        allow(model).to receive(:generate_stream).and_return(chunks)

        result = instance.generate_with_streaming(messages, tools:)
        events = drain_events

        token_events = events.select { |e| e.is_a?(Smolagents::Events::ModelTokenGenerated) }
        expect(token_events.size).to eq(1)
        expect(result).to eq("ok")
      end

      it "skips empty tokens" do
        chunks = [double(content: ""), double(content: "ok")]
        allow(model).to receive(:generate_stream).and_return(chunks)

        result = instance.generate_with_streaming(messages, tools:)
        events = drain_events

        token_events = events.select { |e| e.is_a?(Smolagents::Events::ModelTokenGenerated) }
        expect(token_events.size).to eq(1)
        expect(result).to eq("ok")
      end

      it "tracks accumulated content in events" do
        chunks = [double(content: "a"), double(content: "b"), double(content: "c")]
        allow(model).to receive(:generate_stream).and_return(chunks)

        instance.generate_with_streaming(messages, tools:)
        events = drain_events

        token_events = events.select { |e| e.is_a?(Smolagents::Events::ModelTokenGenerated) }
        accumulated = token_events.map(&:accumulated_content)
        expect(accumulated).to eq(%w[a ab abc])
      end

      it "uses ctx step_number when available" do
        instance.ctx = double("ctx", step_number: 7)
        chunks = [double(content: "x")]
        allow(model).to receive(:generate_stream).and_return(chunks)

        instance.generate_with_streaming(messages, tools:)
        events = drain_events

        token_events = events.select { |e| e.is_a?(Smolagents::Events::ModelTokenGenerated) }
        expect(token_events.first.step_number).to eq(7)
      end

      it "defaults step_number to 0 when ctx is nil" do
        instance.ctx = nil
        chunks = [double(content: "x")]
        allow(model).to receive(:generate_stream).and_return(chunks)

        instance.generate_with_streaming(messages, tools:)
        events = drain_events

        token_events = events.select { |e| e.is_a?(Smolagents::Events::ModelTokenGenerated) }
        expect(token_events.first.step_number).to eq(0)
      end
    end
  end

  describe "#streamable?" do
    it "returns false when streaming disabled" do
      allow(model).to receive(:respond_to?).with(:generate_stream).and_return(true)
      expect(instance.streamable?).to be false
    end

    it "returns false when model lacks generate_stream" do
      instance.enable_token_streaming!
      allow(model).to receive(:respond_to?).with(:generate_stream).and_return(false)
      expect(instance.streamable?).to be false
    end

    it "returns true when both conditions met" do
      instance.enable_token_streaming!
      allow(model).to receive(:respond_to?).with(:generate_stream).and_return(true)
      expect(instance.streamable?).to be true
    end
  end

  describe "#emit_token_if_present" do
    it "handles chunks responding to content" do
      accumulated = +""
      chunk = double(content: "hello")

      instance.emit_token_if_present(chunk, accumulated, 0)

      expect(accumulated).to eq("hello")
    end

    it "handles chunks not responding to content via to_s" do
      accumulated = +""
      chunk = "raw_token"

      instance.emit_token_if_present(chunk, accumulated, 0)

      expect(accumulated).to eq("raw_token")
    end
  end
end
