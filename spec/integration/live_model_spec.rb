# Integration tests that run against real LLM servers.
# These are skipped by default - run with: LIVE_MODEL_TESTS=1 bundle exec rspec spec/integration/
#
# Server configuration:
#   LM_STUDIO_URL - LM Studio server (default: http://localhost:1234/v1)
#   LLAMA_CPP_URL - llama-cpp server (default: https://llama-cpp-ultra.reverse-bull.ts.net/v1)
#   SEARXNG_URL   - SearXNG search (default: https://searxng.reverse-bull.ts.net)

RSpec.describe "Live Model Integration", :integration, skip: !ENV["LIVE_MODEL_TESTS"] do
  before(:all) do
    # Enable logging for visibility into timing
    Smolagents::Telemetry::LoggingSubscriber.enable(level: :debug)
  end

  after(:all) do
    Smolagents::Telemetry::LoggingSubscriber.disable
  end

  let(:lm_studio_url) { ENV.fetch("LM_STUDIO_URL", "http://localhost:1234/v1") }
  let(:llama_cpp_url) { ENV.fetch("LLAMA_CPP_URL", "https://llama-cpp-ultra.reverse-bull.ts.net/v1") }

  def check_server(url)
    uri = URI.parse("#{url}/models")
    response = Net::HTTP.get_response(uri)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    false
  end

  describe "LM Studio connection" do
    before do
      skip "LM Studio not available" unless check_server(lm_studio_url)
    end

    let(:model) do
      Smolagents::Models::OpenAIModel.new(
        model_id: "gpt-oss-20b",
        api_base: lm_studio_url,
        api_key: "not-needed"
      )
    end

    it "can generate a simple response" do
      response = model.generate([
                                  Smolagents::Types::ChatMessage.user("What is 2+2? Reply with just the number.")
                                ])

      expect(response).to be_a(Smolagents::Types::ChatMessage)
      expect(response.content).to include("4")
    end
  end

  describe "llama-cpp connection" do
    before do
      skip "llama-cpp not available" unless check_server(llama_cpp_url)
    end

    let(:model) do
      Smolagents::Models::OpenAIModel.new(
        model_id: "LFM2.5-1.2B-Instruct-BF16",
        api_base: llama_cpp_url,
        api_key: "not-needed"
      )
    end

    it "can generate a simple response" do
      response = model.generate([
                                  Smolagents::Types::ChatMessage.user("What is 2+2? Reply with just the number.")
                                ])

      expect(response).to be_a(Smolagents::Types::ChatMessage)
      expect(response.content).to include("4")
    end
  end

  describe "CodeAgent with calculator", :slow do
    before do
      skip "LM Studio not available" unless check_server(lm_studio_url)
    end

    let(:model) do
      Smolagents::Models::OpenAIModel.new(
        model_id: "gpt-oss-20b",
        api_base: lm_studio_url,
        api_key: "not-needed"
      )
    end

    let(:calculator) do
      Smolagents::Tools.define_tool(
        "calculate",
        description: "Evaluate a mathematical expression. Example: calculate(expression: '2 + 2')",
        inputs: { "expression" => { "type" => "string", "description" => "Math expression to evaluate" } },
        output_type: "number"
        # rubocop:disable Security/Eval -- Test calculator with controlled input
      ) { |expression:| eval(expression).to_f }
      # rubocop:enable Security/Eval
    end

    let(:agent) do
      Smolagents::Agents::Agent.new(
        model:,
        tools: [calculator],
        max_steps: 5
      )
    end

    it "can solve a simple math problem" do
      result = agent.run("What is 15 * 7?")
      expect(result.output.to_s).to include("105")
    end
  end

  describe "CodeAgent with search", :slow do
    before do
      skip "LM Studio not available" unless check_server(lm_studio_url)
    end

    let(:model) do
      Smolagents::Models::OpenAIModel.new(
        model_id: "gpt-oss-20b",
        api_base: lm_studio_url,
        api_key: "not-needed"
      )
    end

    let(:searxng_url) { ENV.fetch("SEARXNG_URL", "https://searxng.reverse-bull.ts.net") }

    let(:search_tool) do
      Smolagents::Tools::SearxngSearchTool.new(instance_url: searxng_url)
    end

    let(:agent) do
      Smolagents::Agents::Agent.new(
        model:,
        tools: [search_tool],
        max_steps: 8
      )
    end

    it "can search the web" do
      result = agent.run("What is the current Ruby stable version?")

      # Verify that the agent called the search tool (proves tool calling works)
      search_step = result.steps.find { |s| s.respond_to?(:code_action) && s.code_action&.include?("searxng_search") }
      expect(search_step).not_to be_nil, "Expected agent to call searxng_search tool"
    end
  end
end
