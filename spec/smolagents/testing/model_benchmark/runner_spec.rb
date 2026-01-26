require "spec_helper"

RSpec.describe Smolagents::Testing::ModelBenchmark::Runner do
  # Create a test class that includes the Runner module
  let(:test_class) do
    Class.new do
      include Smolagents::Testing::ModelBenchmark::Runner
      include Smolagents::Testing::ModelBenchmark::BenchmarkTools

      attr_accessor :base_url

      def initialize
        @base_url = "http://localhost:1234/v1"
      end
    end
  end

  let(:runner) { test_class.new }

  describe "TEST_RUNNERS constant" do
    it "maps test types to runner methods" do
      expect(Smolagents::Testing::ModelBenchmark::Runner::TEST_RUNNERS).to eq(
        {
          chat: :run_chat_test,
          agent: :run_agent_test,
          vision: :run_vision_test
        }
      )
    end
  end

  describe "#run_test" do
    context "with chat test type" do
      let(:chat_test) do
        {
          name: "basic_chat",
          level: 1,
          type: :chat,
          prompt: "What is 2 + 2?",
          validator: ->(response) { response.to_s.include?("4") }
        }
      end

      it "returns BenchmarkResult on successful chat test" do
        stub_request(:post, "http://localhost:1234/v1/chat/completions")
          .to_return(
            status: 200,
            body: {
              choices: [{ message: { content: "The answer is 4" } }],
              usage: { prompt_tokens: 10, completion_tokens: 5 }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = runner.run_test("test-model", chat_test, timeout: 30)

        expect(result).to be_a(Smolagents::Testing::BenchmarkResult)
        expect(result.passed?).to be true
        expect(result.test_name).to eq("basic_chat")
        expect(result.level).to eq(1)
      end

      it "returns failure when validation fails" do
        stub_request(:post, "http://localhost:1234/v1/chat/completions")
          .to_return(
            status: 200,
            body: {
              choices: [{ message: { content: "I don't know" } }],
              usage: { prompt_tokens: 10, completion_tokens: 5 }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = runner.run_test("test-model", chat_test, timeout: 30)

        expect(result.passed?).to be false
        expect(result.error).to eq("Validation failed")
      end

      it "captures server error as failure", max_time: 5 do
        stub_request(:post, "http://localhost:1234/v1/chat/completions")
          .to_return(status: 500, body: '{"error": "Internal error"}')

        result = runner.run_test("test-model", chat_test, timeout: 30)

        expect(result.passed?).to be false
        expect(result.error).to include("Faraday::ServerError")
        expect(result.duration).to eq(0)
      end
    end

    context "with vision test type" do
      let(:vision_test) do
        {
          name: "vision_test",
          level: 6,
          type: :vision,
          prompt: "What do you see?",
          image_url: "https://example.com/image.png",
          validator: ->(response) { response.to_s.downcase.include?("red") }
        }
      end

      it "returns BenchmarkResult for vision test" do
        # Stub any POST to the chat completions endpoint
        stub_request(:post, "http://localhost:1234/v1/chat/completions")
          .with(body: hash_including("messages" => anything))
          .to_return(
            status: 200,
            body: {
              choices: [{ message: { content: "I see a red ruby gem" } }],
              usage: { prompt_tokens: 50, completion_tokens: 10 }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = runner.run_test("vision-model", vision_test, timeout: 30)

        expect(result).to be_a(Smolagents::Testing::BenchmarkResult)
        expect(result.test_name).to eq("vision_test")
        expect(result.level).to eq(6)
      end

      it "captures errors from vision processing" do
        # Vision test may fail due to image processing issues
        stub_request(:post, "http://localhost:1234/v1/chat/completions")
          .to_return(status: 500, body: '{"error": "Model error"}')

        result = runner.run_test("vision-model", vision_test, timeout: 30)

        expect(result.passed?).to be false
        expect(result.duration).to eq(0)
      end
    end

    context "with agent test type" do
      let(:agent_test) do
        {
          name: "tool_call",
          level: 3,
          type: :agent,
          tools: [:calculator],
          max_steps: 3,
          task: "Calculate 15 * 7",
          validator: ->(r) { r.success? && r.output.to_s.include?("105") }
        }
      end

      it "builds agent and runs task" do
        # First call: model generates code to call calculator
        stub_request(:post, "http://localhost:1234/v1/chat/completions")
          .to_return(
            {
              status: 200,
              body: {
                choices: [{ message: { content: "```ruby\nresult = calculate(expression: \"15 * 7\")\n```" } }],
                usage: { prompt_tokens: 100, completion_tokens: 20 }
              }.to_json,
              headers: { "Content-Type" => "application/json" }
            },
            {
              status: 200,
              body: {
                choices: [{ message: { content: "```ruby\nfinal_answer(answer: \"105\")\n```" } }],
                usage: { prompt_tokens: 150, completion_tokens: 15 }
              }.to_json,
              headers: { "Content-Type" => "application/json" }
            }
          )

        result = runner.run_test("test-model", agent_test, timeout: 60)

        expect(result).to be_a(Smolagents::Testing::BenchmarkResult)
        expect(result.test_name).to eq("tool_call")
        expect(result.level).to eq(3)
      end
    end

    context "with unknown test type" do
      let(:unknown_test) do
        {
          name: "unknown",
          level: 1,
          type: :unknown,
          prompt: "Test"
        }
      end

      it "raises KeyError for unknown type" do
        result = runner.run_test("test-model", unknown_test, timeout: 30)

        expect(result.passed?).to be false
        expect(result.error).to include("KeyError")
      end
    end
  end
end
