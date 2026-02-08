require "spec_helper"

# Integration tests for FunctionGemma with LM Studio
# These tests require a running LM Studio instance with FunctionGemma loaded.
# Run with: bundle exec rspec spec/integration/function_gemma_spec.rb

RSpec.describe "FunctionGemma Integration", :integration do
  let(:model) do
    Smolagents::OpenAIModel.lm_studio("functiongemma-270m-it-mlx")
  end

  let(:search_tool) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "search"
      self.description = "Search the web for information"
      self.inputs = { query: { type: "string", description: "The search query" } }
      self.output_type = "string"
      def execute(query:) = "Results for: #{query}"
    end.new
  end

  describe "via LM Studio OpenAI-compatible API" do
    it "produces tool calls through standard tools API" do
      messages = [
        Smolagents::ChatMessage.system("You are a helpful assistant."),
        Smolagents::ChatMessage.user("Search for Ruby 4.0 release notes")
      ]

      result = model.generate(messages, tools: [search_tool])

      expect(result.tool_calls).not_to be_empty
      expect(result.tool_calls.first.name).to eq("search")
      expect(result.tool_calls.first.arguments).to have_key("query")
    end

    it "handles multiple tool selections" do
      calc_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "calculate"
        self.description = "Calculate a mathematical expression"
        self.inputs = { expression: { type: "string", description: "Math expression" } }
        self.output_type = "string"
        def execute(expression:) = "294" # Mocked result for 42 * 7
      end.new

      messages = [
        Smolagents::ChatMessage.system("You are a helpful assistant."),
        Smolagents::ChatMessage.user("Calculate 42 * 7")
      ]

      result = model.generate(messages, tools: [search_tool, calc_tool])

      expect(result.tool_calls).not_to be_empty
      expect(result.tool_calls.first.name).to eq("calculate")
    end
  end

  describe "raw output parsing (for non-LM Studio backends)" do
    # When using FunctionGemma directly without OpenAI-compatible wrapper,
    # we need to parse the raw output format.

    it "parses <start_function_call> format" do
      raw_output = "<start_function_call>call:search{query:<escape>Ruby 4.0<escape>}<end_function_call>"
      calls = Smolagents::Models::FunctionGemma::Parser.parse(raw_output)

      expect(calls.size).to eq(1)
      expect(calls.first.name).to eq("search")
      expect(calls.first.arguments["query"]).to eq("Ruby 4.0")
    end
  end

  describe "confidence-based dispatch" do
    let(:tools) { { "search" => search_tool } }

    it "routes high-confidence calls to execute" do
      raw_output = "<start_function_call>call:search{query:<escape>test<escape>}<end_function_call>"
      result = Smolagents::Models::FunctionGemma::Dispatcher.dispatch(raw_output, tools:)

      expect(result.execute?).to be true
      expect(result.tool_calls.first.high_confidence?).to be true
    end

    it "routes unknown tools to delegate" do
      raw_output = "<start_function_call>call:unknown_tool{}<end_function_call>"
      result = Smolagents::Models::FunctionGemma::Dispatcher.dispatch(raw_output, tools:)

      expect(result.delegate?).to be true
    end
  end
end
