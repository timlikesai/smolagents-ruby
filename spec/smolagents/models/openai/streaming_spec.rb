require "smolagents/models/model"
require "smolagents/models/openai_model"
require "smolagents/models/openai/streaming"

RSpec.describe Smolagents::Models::OpenAI::Streaming do
  let(:model_class) do
    Class.new do
      include Smolagents::Models::OpenAI::Streaming

      attr_accessor :client, :model_id, :temperature

      def initialize
        @model_id = "gpt-4"
        @temperature = 0.7
      end

      def with_circuit_breaker(_name)
        yield
      end

      def format_messages(messages)
        messages.map { |msg| { role: msg.role.to_s, content: msg.content } }
      end
    end
  end
  let(:mock_client) { double("OpenAI::Client") }
  let(:model) do
    m = model_class.new
    m.client = mock_client
    m
  end
  let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

  describe "#generate_stream" do
    context "without block" do
      it "returns an Enumerator" do
        result = model.generate_stream(messages)

        expect(result).to be_a(Enumerator)
      end

      it "allows lazy evaluation" do
        result = model.generate_stream(messages)

        expect(result.lazy).to be_a(Enumerator::Lazy)
      end

      it "can be iterated with each" do
        mock_response = {
          "choices" => [{ "delta" => { "content" => "Hello" } }]
        }
        allow(mock_client).to receive(:chat).and_yield(mock_response, nil)

        result = model.generate_stream(messages)
        chunks = result.take(1).to_a

        expect(chunks.length).to eq(1)
      end
    end

    context "with block" do
      it "yields ChatMessage chunks" do
        mock_response = {
          "choices" => [{ "delta" => { "content" => "Hello" } }]
        }
        allow(mock_client).to receive(:chat).and_yield(mock_response, nil)

        chunks = []
        model.generate_stream(messages) { |chunk| chunks << chunk }

        expect(chunks.length).to eq(1)
        expect(chunks[0]).to be_a(Smolagents::ChatMessage)
      end

      it "yields assistant role messages" do
        mock_response = {
          "choices" => [{ "delta" => { "content" => "Hi" } }]
        }
        allow(mock_client).to receive(:chat).and_yield(mock_response, nil)

        chunks = []
        model.generate_stream(messages) { |chunk| chunks << chunk }

        expect(chunks[0].role).to eq(:assistant)
      end

      it "accumulates content from multiple chunks" do
        chunk1 = { "choices" => [{ "delta" => { "content" => "Hello" } }] }
        chunk2 = { "choices" => [{ "delta" => { "content" => " world" } }] }
        allow(mock_client).to receive(:chat).and_yield(chunk1, nil).and_yield(chunk2, nil)

        contents = []
        model.generate_stream(messages) { |chunk| contents << chunk.content }

        expect(contents).to eq(["Hello", " world"])
      end

      it "handles chunks without content" do
        chunk_no_content = { "choices" => [{ "delta" => {} }] }
        chunk_with_content = { "choices" => [{ "delta" => { "content" => "text" } }] }

        allow(mock_client).to receive(:chat).and_yield(chunk_no_content, nil).and_yield(chunk_with_content, nil)

        chunks = []
        model.generate_stream(messages) { |chunk| chunks << chunk }

        # Both chunks yield - implementation yields all deltas
        expect(chunks.length).to eq(2)
        expect(chunks[1].content).to eq("text")
      end

      it "includes raw chunk data in ChatMessage" do
        raw_chunk = { "choices" => [{ "delta" => { "content" => "test" } }] }
        allow(mock_client).to receive(:chat).and_yield(raw_chunk, nil)

        chunks = []
        model.generate_stream(messages) { |chunk| chunks << chunk }

        expect(chunks[0].raw).to eq(raw_chunk)
      end

      it "includes tool calls in delta when present" do
        tool_delta = {
          "choices" => [{
            "delta" => {
              "content" => "calling",
              "tool_calls" => [{ id: "call_123", type: "function", function: { name: "search" } }]
            }
          }]
        }
        allow(mock_client).to receive(:chat).and_yield(tool_delta, nil)

        chunks = []
        model.generate_stream(messages) { |chunk| chunks << chunk }

        expect(chunks[0].tool_calls).to be_a(Array)
      end

      it "handles empty choices array" do
        empty_response = { "choices" => [] }
        chunk_with_content = { "choices" => [{ "delta" => { "content" => "text" } }] }

        allow(mock_client).to receive(:chat).and_yield(empty_response, nil).and_yield(chunk_with_content, nil)

        chunks = []
        model.generate_stream(messages) { |chunk| chunks << chunk }

        expect(chunks.length).to eq(1)
      end

      it "handles missing delta key" do
        response_no_delta = { "choices" => [{}] }
        response_with_delta = { "choices" => [{ "delta" => { "content" => "text" } }] }

        allow(mock_client).to receive(:chat).and_yield(response_no_delta, nil).and_yield(response_with_delta, nil)

        chunks = []
        model.generate_stream(messages) { |chunk| chunks << chunk }

        expect(chunks.length).to eq(1)
      end
    end

    it "calls client.chat with formatted parameters" do
      allow(mock_client).to receive(:chat).with(hash_including(:parameters))
      model.generate_stream(messages) { |_chunk| break }
      expect(mock_client).to have_received(:chat).with(hash_including(:parameters))
    end

    it "uses circuit breaker for reliability" do
      allow(mock_client).to receive(:chat)
      allow(model).to receive(:with_circuit_breaker).with("openai_api").and_call_original
      model.generate_stream(messages) { |_chunk| break }
      expect(model).to have_received(:with_circuit_breaker).with("openai_api")
    end

    it "passes messages to build_stream_params" do
      allow(mock_client).to receive(:chat)
      allow(model).to receive(:format_messages).and_call_original

      model.generate_stream(messages) { |_chunk| break }

      expect(model).to have_received(:format_messages)
    end
  end

  describe "#build_stream_params" do
    it "includes model_id" do
      params = model.send(:build_stream_params, messages)

      expect(params).to have_key(:model)
      expect(params[:model]).to eq("gpt-4")
    end

    it "includes formatted messages" do
      params = model.send(:build_stream_params, messages)

      expect(params).to have_key(:messages)
      expect(params[:messages]).to be_an(Array)
    end

    it "includes temperature from instance" do
      model.temperature = 0.5
      params = model.send(:build_stream_params, messages)

      expect(params).to have_key(:temperature)
      expect(params[:temperature]).to eq(0.5)
    end

    it "includes stream: true flag" do
      params = model.send(:build_stream_params, messages)

      expect(params).to have_key(:stream)
      expect(params[:stream]).to be true
    end
  end

  describe "#yield_stream_chunk" do
    it "yields ChatMessage when delta contains content" do
      chunk = { "choices" => [{ "delta" => { "content" => "Hello" } }] }

      result = []
      model.send(:yield_stream_chunk, chunk) { |msg| result << msg }

      expect(result.length).to eq(1)
      expect(result[0]).to be_a(Smolagents::ChatMessage)
      expect(result[0].content).to eq("Hello")
    end

    it "skips chunks without delta" do
      chunk = { "choices" => [{}] }

      result = []
      model.send(:yield_stream_chunk, chunk) { |msg| result << msg }

      expect(result).to be_empty
    end

    it "yields ChatMessage with nil content for empty delta" do
      chunk = { "choices" => [{ "delta" => {} }] }

      result = []
      model.send(:yield_stream_chunk, chunk) { |msg| result << msg }

      # Implementation yields for all deltas, including empty ones
      expect(result.length).to eq(1)
      expect(result[0].content).to be_nil
    end

    it "includes raw chunk in ChatMessage" do
      chunk = { "choices" => [{ "delta" => { "content" => "test" } }] }

      result = []
      model.send(:yield_stream_chunk, chunk) { |msg| result << msg }

      expect(result[0].raw).to eq(chunk)
    end

    it "yields ChatMessage with nil content when content is nil" do
      chunk = { "choices" => [{ "delta" => { "content" => nil } }] }

      result = []
      model.send(:yield_stream_chunk, chunk) { |msg| result << msg }

      # Implementation yields for all deltas, including those with nil content
      expect(result.length).to eq(1)
      expect(result[0].content).to be_nil
    end

    it "includes tool_calls in delta" do
      chunk = {
        "choices" => [{
          "delta" => {
            "content" => "calling",
            "tool_calls" => [{ id: "call_1", type: "function" }]
          }
        }]
      }

      result = []
      model.send(:yield_stream_chunk, chunk) { |msg| result << msg }

      expect(result[0].tool_calls).to eq([{ id: "call_1", type: "function" }])
    end
  end
end
