require "smolagents/models/model"
require "smolagents/models/anthropic_model"
require "smolagents/models/anthropic/streaming"

RSpec.describe Smolagents::Models::Anthropic::Streaming do
  let(:model_class) do
    Class.new do
      include Smolagents::Models::Anthropic::Streaming

      attr_accessor :client
    end
  end
  let(:mock_client) { double("Anthropic::Client") }
  let(:model) do
    m = model_class.new
    m.client = mock_client
    m
  end

  describe "#stream_messages" do
    it "yields ChatMessage chunks for text deltas" do
      chunk = {
        "type" => "content_block_delta",
        "delta" => { "type" => "text_delta", "text" => "Hello" }
      }
      allow(model.client).to receive(:messages).and_yield(chunk)

      results = []
      model.stream_messages({}) { |msg| results << msg }

      expect(results.length).to eq(1)
      expect(results[0]).to be_a(Smolagents::ChatMessage)
      expect(results[0].content).to eq("Hello")
    end

    it "yields assistant role messages" do
      chunk = {
        "type" => "content_block_delta",
        "delta" => { "type" => "text_delta", "text" => "Response" }
      }
      allow(model.client).to receive(:messages).and_yield(chunk)

      results = []
      model.stream_messages({}) { |msg| results << msg }

      expect(results[0].role).to eq(:assistant)
    end

    it "skips non-text-delta chunks" do
      text_chunk = {
        "type" => "content_block_delta",
        "delta" => { "type" => "text_delta", "text" => "Hello" }
      }
      non_text_chunk = {
        "type" => "content_block_start",
        "content_block" => { "type" => "text" }
      }
      allow(model.client).to receive(:messages).and_yield(non_text_chunk).and_yield(text_chunk)

      results = []
      model.stream_messages({}) { |msg| results << msg }

      expect(results.length).to eq(1)
      expect(results[0].content).to eq("Hello")
    end

    it "includes raw chunk data" do
      chunk = {
        "type" => "content_block_delta",
        "delta" => { "type" => "text_delta", "text" => "test" }
      }
      allow(model.client).to receive(:messages).and_yield(chunk)

      results = []
      model.stream_messages({}) { |msg| results << msg }

      expect(results[0].raw).to eq(chunk)
    end

    it "handles multiple chunks accumulating content" do
      chunk1 = {
        "type" => "content_block_delta",
        "delta" => { "type" => "text_delta", "text" => "Hello" }
      }
      chunk2 = {
        "type" => "content_block_delta",
        "delta" => { "type" => "text_delta", "text" => " world" }
      }
      allow(model.client).to receive(:messages).and_yield(chunk1).and_yield(chunk2)

      results = []
      model.stream_messages({}) { |msg| results << msg }

      expect(results.length).to eq(2)
      expect(results[0].content).to eq("Hello")
      expect(results[1].content).to eq(" world")
    end

    it "passes params to client.messages" do
      params = { model: "claude-3", messages: [] }
      allow(model.client).to receive(:messages)

      model.stream_messages(params) { |msg| break }

      expect(model.client).to have_received(:messages).with(parameters: params)
    end

    it "handles non-hash chunks gracefully" do
      text_chunk = {
        "type" => "content_block_delta",
        "delta" => { "type" => "text_delta", "text" => "Hello" }
      }
      allow(model.client).to receive(:messages).and_yield("not a hash").and_yield(text_chunk)

      results = []
      model.stream_messages({}) { |msg| results << msg }

      expect(results.length).to eq(1)
      expect(results[0].content).to eq("Hello")
    end

    it "handles chunks with missing delta" do
      chunk_no_delta = { "type" => "content_block_start" }
      chunk_with_delta = {
        "type" => "content_block_delta",
        "delta" => { "type" => "text_delta", "text" => "text" }
      }
      allow(model.client).to receive(:messages).and_yield(chunk_no_delta).and_yield(chunk_with_delta)

      results = []
      model.stream_messages({}) { |msg| results << msg }

      expect(results.length).to eq(1)
      expect(results[0].content).to eq("text")
    end
  end

  describe "#text_delta_chunk?" do
    it "returns true for text delta chunks" do
      chunk = {
        "type" => "content_block_delta",
        "delta" => { "type" => "text_delta", "text" => "Hello" }
      }

      result = model.send(:text_delta_chunk?, chunk)

      expect(result).to be true
    end

    it "returns false for non-dict chunks" do
      result = model.send(:text_delta_chunk?, "string")

      expect(result).to be false
    end

    it "returns false for chunks without content_block_delta type" do
      chunk = {
        "type" => "message_start",
        "delta" => { "type" => "text_delta", "text" => "Hello" }
      }

      result = model.send(:text_delta_chunk?, chunk)

      expect(result).to be false
    end

    it "returns false when delta type is not text_delta" do
      chunk = {
        "type" => "content_block_delta",
        "delta" => { "type" => "input_json_delta", "partial_json" => "{}" }
      }

      result = model.send(:text_delta_chunk?, chunk)

      expect(result).to be false
    end

    it "returns false when delta is missing" do
      chunk = { "type" => "content_block_delta" }

      result = model.send(:text_delta_chunk?, chunk)

      expect(result).to be false
    end

    it "returns false for empty hash" do
      result = model.send(:text_delta_chunk?, {})

      expect(result).to be false
    end

    it "returns false when delta is nil" do
      chunk = {
        "type" => "content_block_delta",
        "delta" => nil
      }

      result = model.send(:text_delta_chunk?, chunk)

      expect(result).to be false
    end

    it "validates all required conditions" do
      # Must be a Hash
      expect(model.send(:text_delta_chunk?, [])).to be false

      # Must have content_block_delta type
      expect(model.send(:text_delta_chunk?, { "type" => "other" })).to be false

      # Must have delta key
      expect(model.send(:text_delta_chunk?, { "type" => "content_block_delta" })).to be false

      # Delta must have text_delta type
      expect(model.send(:text_delta_chunk?, {
                          "type" => "content_block_delta",
                          "delta" => { "type" => "other" }
                        })).to be false

      # Valid case
      expect(model.send(:text_delta_chunk?, {
                          "type" => "content_block_delta",
                          "delta" => { "type" => "text_delta", "text" => "ok" }
                        })).to be true
    end
  end
end
