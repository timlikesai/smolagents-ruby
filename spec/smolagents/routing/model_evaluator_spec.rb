require "smolagents"

RSpec.describe Smolagents::Routing::ModelEvaluator do
  subject(:evaluator) { described_class.new(base_url: "http://localhost:1234/v1") }

  # Helper to suppress stdout during tests that produce output
  def suppress_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original_stdout
  end

  describe "TestCase" do
    let(:test_case) do
      described_class::TestCase.new(
        name: "search_test",
        task: "Search for Ruby",
        expected_tool: "search",
        expected_args_keys: [:query]
      )
    end

    describe "#matches?" do
      it "returns true when tool call matches" do
        tool_call = Smolagents::Types::ToolCall.new(
          name: "search",
          arguments: { "query" => "Ruby" },
          id: "tc_1"
        )
        expect(test_case.matches?(tool_call)).to be true
      end

      it "returns false when tool name differs" do
        tool_call = Smolagents::Types::ToolCall.new(
          name: "other_tool",
          arguments: { "query" => "Ruby" },
          id: "tc_1"
        )
        expect(test_case.matches?(tool_call)).to be false
      end

      it "returns false when required arg is missing" do
        tool_call = Smolagents::Types::ToolCall.new(
          name: "search",
          arguments: { "other_arg" => "value" },
          id: "tc_1"
        )
        expect(test_case.matches?(tool_call)).to be false
      end

      it "returns false for nil tool call" do
        expect(test_case.matches?(nil)).to be false
      end
    end
  end

  describe "TestResult" do
    let(:test_case) do
      described_class::TestCase.new(
        name: "test",
        task: "task",
        expected_tool: "search",
        expected_args_keys: []
      )
    end

    describe "#passed?" do
      it "returns true when success is true" do
        result = described_class::TestResult.new(
          test_case:, model_id: "model", success: true,
          tool_call: nil, latency_ms: 100, error: nil
        )
        expect(result.passed?).to be true
        expect(result.failed?).to be false
      end
    end

    describe "#failed?" do
      it "returns true when success is false" do
        result = described_class::TestResult.new(
          test_case:, model_id: "model", success: false,
          tool_call: nil, latency_ms: 100, error: nil
        )
        expect(result.failed?).to be true
        expect(result.passed?).to be false
      end
    end
  end

  describe "ModelResult" do
    let(:test_case) { described_class::TestCase.new(name: "t", task: "t", expected_tool: "x", expected_args_keys: []) }
    let(:pass_result) { described_class::TestResult.new(test_case:, model_id: "m", success: true, tool_call: nil, latency_ms: 50, error: nil) }
    let(:fail_result) { described_class::TestResult.new(test_case:, model_id: "m", success: false, tool_call: nil, latency_ms: 100, error: RuntimeError.new("boom")) }

    subject(:model_result) do
      described_class::ModelResult.new(model_id: "test-model", test_results: [pass_result, fail_result], total_latency_ms: 150)
    end

    it "calculates pass_count" do
      expect(model_result.pass_count).to eq(1)
    end

    it "calculates fail_count" do
      expect(model_result.fail_count).to eq(1)
    end

    it "calculates accuracy" do
      expect(model_result.accuracy).to eq(0.5)
    end

    it "calculates avg_latency_ms" do
      expect(model_result.avg_latency_ms).to eq(75.0)
    end

    it "collects error_types" do
      expect(model_result.error_types).to eq([RuntimeError])
    end

    context "with no results" do
      subject(:empty_result) { described_class::ModelResult.new(model_id: "m", test_results: [], total_latency_ms: 0) }

      it "returns 0 for accuracy" do
        expect(empty_result.accuracy).to eq(0.0)
      end

      it "returns 0 for avg_latency" do
        expect(empty_result.avg_latency_ms).to eq(0.0)
      end
    end
  end

  describe "STANDARD_TEST_CASES" do
    it "includes test cases for common patterns" do
      names = described_class::STANDARD_TEST_CASES.map(&:name)
      expect(names).to include("simple_search", "calculation", "weather_lookup")
    end
  end

  describe "STANDARD_TOOLS" do
    it "defines tools for standard test cases" do
      names = described_class::STANDARD_TOOLS.map { |t| t[:name] }
      expect(names).to include("search", "calculate", "get_weather")
    end
  end

  describe "#available_models" do
    context "when server responds" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(body: '{"data": [{"id": "model1"}, {"id": "model2"}]}')
      end

      it "returns list of model IDs" do
        expect(evaluator.available_models).to eq(%w[model1 model2])
      end
    end

    context "when server fails" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_raise(Errno::ECONNREFUSED)
      end

      it "returns empty array" do
        suppress_output do
          expect(evaluator.available_models).to eq([])
        end
      end
    end
  end

  describe "#evaluate_model" do
    let(:tool_response) do
      {
        "choices" => [{
          "message" => {
            "tool_calls" => [{
              "id" => "tc_1",
              "function" => {
                "name" => "search",
                "arguments" => '{"query": "Ruby programming tutorials"}'
              }
            }]
          }
        }]
      }
    end

    let(:simple_test_cases) do
      [
        described_class::TestCase.new(
          name: "search_test",
          task: "Search for Ruby",
          expected_tool: "search",
          expected_args_keys: [:query]
        )
      ]
    end

    before do
      stub_request(:post, "http://localhost:1234/v1/chat/completions")
        .to_return(body: tool_response.to_json)
    end

    it "returns ModelResult with test results" do
      result = evaluator.evaluate_model("test-model", test_cases: simple_test_cases)

      expect(result).to be_a(described_class::ModelResult)
      expect(result.model_id).to eq("test-model")
      expect(result.test_results.size).to eq(1)
    end

    it "tracks success for matching tool calls" do
      result = evaluator.evaluate_model("test-model", test_cases: simple_test_cases)

      expect(result.pass_count).to eq(1)
      expect(result.accuracy).to eq(1.0)
    end

    it "records latency" do
      result = evaluator.evaluate_model("test-model", test_cases: simple_test_cases)

      expect(result.total_latency_ms).to be > 0
    end
  end

  describe "#evaluate_all" do
    let(:tool_response) do
      { "choices" => [{ "message" => { "tool_calls" => nil } }] }
    end

    before do
      stub_request(:get, "http://localhost:1234/v1/models")
        .to_return(body: '{"data": [{"id": "model-a"}, {"id": "model-b"}]}')
      stub_request(:post, "http://localhost:1234/v1/chat/completions")
        .to_return(body: tool_response.to_json)
    end

    let(:simple_test_cases) do
      [described_class::TestCase.new(name: "t", task: "t", expected_tool: nil, expected_args_keys: [])]
    end

    # Suppress the "Evaluating: model..." output
    around { |example| suppress_output { example.run } }

    it "evaluates all available models" do
      results = evaluator.evaluate_all(test_cases: simple_test_cases)

      expect(results.size).to eq(2)
      expect(results.map(&:model_id)).to contain_exactly("model-a", "model-b")
    end

    it "filters models when filter provided" do
      results = evaluator.evaluate_all(filter: /model-a/, test_cases: simple_test_cases)

      expect(results.size).to eq(1)
      expect(results.first.model_id).to eq("model-a")
    end
  end

  describe "#print_report" do
    let(:test_case) { described_class::TestCase.new(name: "t", task: "t", expected_tool: "x", expected_args_keys: []) }
    let(:pass_result) { described_class::TestResult.new(test_case:, model_id: "m", success: true, tool_call: nil, latency_ms: 50, error: nil) }

    it "outputs formatted report" do
      model_result = described_class::ModelResult.new(
        model_id: "test-model",
        test_results: [pass_result],
        total_latency_ms: 50
      )

      expect { evaluator.print_report([model_result]) }.to output(/MODEL EVALUATION REPORT/).to_stdout
    end

    it "shows best accuracy and fastest model" do
      model_result = described_class::ModelResult.new(
        model_id: "test-model",
        test_results: [pass_result],
        total_latency_ms: 50
      )

      expect { evaluator.print_report([model_result]) }.to output(/Best accuracy.*test-model/).to_stdout
    end
  end

  describe "private #extract_tool_call" do
    it "extracts tool call from response" do
      response = {
        "choices" => [{
          "message" => {
            "tool_calls" => [{
              "id" => "tc_123",
              "function" => {
                "name" => "search",
                "arguments" => '{"query": "test"}'
              }
            }]
          }
        }]
      }

      result = evaluator.send(:extract_tool_call, response)

      expect(result).to be_a(Smolagents::Types::ToolCall)
      expect(result.name).to eq("search")
      expect(result.arguments).to eq({ "query" => "test" })
    end

    it "returns nil when no tool calls" do
      response = { "choices" => [{ "message" => { "content" => "text" } }] }

      expect(evaluator.send(:extract_tool_call, response)).to be_nil
    end

    it "handles malformed JSON in arguments" do
      response = {
        "choices" => [{
          "message" => {
            "tool_calls" => [{
              "id" => "tc_1",
              "function" => { "name" => "x", "arguments" => "not json" }
            }]
          }
        }]
      }

      expect(evaluator.send(:extract_tool_call, response)).to be_nil
    end
  end

  describe "private #build_tools" do
    it "builds OpenAI-format tool definitions" do
      tools = evaluator.send(:build_tools)

      expect(tools).to be_an(Array)
      expect(tools.first[:type]).to eq("function")
      expect(tools.first[:function][:name]).to eq("search")
    end
  end
end
