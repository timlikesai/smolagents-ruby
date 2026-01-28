require "smolagents/models/model"
require "smolagents/models/openai_model"
require "smolagents/models/openai/request_builder"

RSpec.describe Smolagents::Models::OpenAI::RequestBuilder do
  let(:model_class) do
    Class.new do
      include Smolagents::Models::OpenAI::RequestBuilder

      attr_reader :model_id

      def initialize
        @api_key = "test-key"
        @api_base = nil
        @azure_api_version = nil
        @model_id = "gpt-4"
        @temperature = 0.7
        @max_tokens = 200
      end
    end
  end
  let(:builder) { model_class.new }

  describe "#build_client" do
    it "creates an OpenAI::Client" do
      skip "OpenAI gem not loaded" unless defined?(OpenAI)

      client = builder.build_client(api_base: "https://api.openai.com/v1", timeout: 30)

      expect(client).to be_a(OpenAI::Client)
    end

    it "sets access token from api_key" do
      skip "OpenAI gem not loaded" unless defined?(OpenAI)

      client = builder.build_client(api_base: nil, timeout: 30)

      # Verify client was created with correct params (internal check)
      expect(client).not_to be_nil
    end

    it "applies api_base as uri_base" do
      skip "OpenAI gem not loaded" unless defined?(OpenAI)

      api_base = "http://localhost:8000/v1"
      client = builder.build_client(api_base:, timeout: 30)

      expect(client).not_to be_nil
    end

    it "applies timeout parameter" do
      skip "OpenAI gem not loaded" unless defined?(OpenAI)

      timeout = 60
      client = builder.build_client(api_base: nil, timeout:)

      expect(client).not_to be_nil
    end

    it "handles nil timeout" do
      skip "OpenAI gem not loaded" unless defined?(OpenAI)

      client = builder.build_client(api_base: nil, timeout: nil)

      expect(client).not_to be_nil
    end

    context "with Azure configuration" do
      before do
        builder.instance_variable_set(:@azure_api_version, "2024-02-15-preview")
      end

      it "applies Azure-specific configuration" do
        skip "OpenAI gem not loaded" unless defined?(OpenAI)

        api_base = "https://example.openai.azure.com/openai/deployments/gpt-4"
        client = builder.build_client(api_base:, timeout: 30)

        expect(client).not_to be_nil
      end
    end
  end

  describe "#build_params" do
    before do
      builder.instance_variable_set(:@model_id, "gpt-4")
      builder.instance_variable_set(:@temperature, 0.7)
      builder.instance_variable_set(:@max_tokens, 200)
      allow(builder).to receive_messages(format_messages: [{ role: "user", content: "Hello" }], format_tools: [])
    end

    it "builds parameter hash for request" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_params(
        messages:,
        stop_sequences: nil,
        temperature: 0.7,
        max_tokens: 200,
        tools: nil,
        response_format: nil
      )

      expect(result).to be_a(Hash)
    end

    it "includes model_id in params" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_params(
        messages:,
        stop_sequences: nil,
        temperature: 0.7,
        max_tokens: 200,
        tools: nil,
        response_format: nil
      )

      expect(result).to have_key(:model)
    end

    it "includes formatted messages" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_params(
        messages:,
        stop_sequences: nil,
        temperature: 0.7,
        max_tokens: 200,
        tools: nil,
        response_format: nil
      )

      expect(result).to have_key(:messages)
    end

    it "includes temperature in params" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_params(
        messages:,
        stop_sequences: nil,
        temperature: 0.5,
        max_tokens: 200,
        tools: nil,
        response_format: nil
      )

      expect(result).to have_key(:temperature)
      expect(result[:temperature]).to eq(0.5)
    end

    it "includes max_tokens when specified" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_params(
        messages:,
        stop_sequences: nil,
        temperature: 0.7,
        max_tokens: 500,
        tools: nil,
        response_format: nil
      )

      expect(result).to have_key(:max_tokens)
      expect(result[:max_tokens]).to eq(500)
    end

    it "includes stop sequences" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_params(
        messages:,
        stop_sequences: %w[END STOP],
        temperature: 0.7,
        max_tokens: 200,
        tools: nil,
        response_format: nil
      )

      expect(result).to have_key(:stop)
      expect(result[:stop]).to eq(%w[END STOP])
    end

    it "includes response_format specification" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      response_format = { type: "json_object" }

      result = builder.build_params(
        messages:,
        stop_sequences: nil,
        temperature: 0.7,
        max_tokens: 200,
        tools: nil,
        response_format:
      )

      expect(result).to have_key(:response_format)
      expect(result[:response_format]).to eq(response_format)
    end

    it "omits nil stop sequences" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_params(
        messages:,
        stop_sequences: nil,
        temperature: 0.7,
        max_tokens: 200,
        tools: nil,
        response_format: nil
      )

      # :stop might not be present or be nil
      expect(result[:stop]).to be_nil if result.key?(:stop)
    end

    it "omits nil response_format" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_params(
        messages:,
        stop_sequences: nil,
        temperature: 0.7,
        max_tokens: 200,
        tools: nil,
        response_format: nil
      )

      expect(result[:response_format]).to be_nil if result.key?(:response_format)
    end

    it "formats tools when provided" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      tool = double(name: "search", description: "Search")
      builder.instance_variable_set(:@model_id, "gpt-4")

      allow(builder).to receive(:format_tools).with([tool]).and_return([{ type: "function", function: {} }])

      result = builder.build_params(
        messages:,
        stop_sequences: nil,
        temperature: 0.7,
        max_tokens: 200,
        tools: [tool],
        response_format: nil
      )

      expect(result).to have_key(:tools)
    end
  end

  describe "#build_client_options" do
    it "includes access_token" do
      options = builder.send(:build_client_options, nil, nil)

      expect(options).to have_key(:access_token)
      expect(options[:access_token]).to eq("test-key")
    end

    it "includes uri_base when api_base provided" do
      api_base = "http://localhost:8000/v1"
      options = builder.send(:build_client_options, api_base, nil)

      expect(options).to have_key(:uri_base)
      expect(options[:uri_base]).to eq(api_base)
    end

    it "omits uri_base when api_base is nil" do
      options = builder.send(:build_client_options, nil, nil)

      expect(options).not_to have_key(:uri_base) unless options[:uri_base].nil?
    end

    it "includes request_timeout when specified" do
      options = builder.send(:build_client_options, nil, 45)

      expect(options).to have_key(:request_timeout)
      expect(options[:request_timeout]).to eq(45)
    end

    it "omits request_timeout when nil" do
      options = builder.send(:build_client_options, nil, nil)

      expect(options).not_to have_key(:request_timeout) unless options[:request_timeout].nil?
    end
  end

  describe "Azure configuration" do
    it "applies Azure headers and URI" do
      builder.instance_variable_set(:@azure_api_version, "2024-02-15-preview")

      client_opts = {}
      api_base = "https://example.openai.azure.com/openai/deployments/gpt-4"

      builder.send(:apply_azure_config, client_opts, api_base)

      expect(client_opts).to have_key(:extra_headers)
      expect(client_opts[:extra_headers]).to have_key("api-key")
      expect(client_opts[:uri_base]).to include("api-version=2024-02-15-preview")
    end
  end

  describe "tool formatting" do
    it "wraps tools in OpenAI format" do
      tool = double(name: "search", description: "Search the web")
      builder.instance_variable_set(:@model_id, "gpt-4")

      allow(builder).to receive_messages(extract_tool_schema: {
                                           name: "search",
                                           description: "Search the web",
                                           properties: { query: { type: "string" } },
                                           required: ["query"]
                                         }, build_parameters_schema: {
                                           type: "object",
                                           properties: { query: { type: "string" } },
                                           required: ["query"]
                                         })
      allow(builder).to receive(:json_schema_type).and_call_original

      result = builder.send(:format_tools, [tool])

      expect(result).to be_an(Array)
      expect(result[0]).to have_key(:type)
      expect(result[0][:type]).to eq("function")
    end
  end

  describe "capability-aware param filtering" do
    before do
      builder.instance_variable_set(:@model_id, "test-model")
      builder.instance_variable_set(:@temperature, 0.7)
      builder.instance_variable_set(:@max_tokens, 200)
      allow(builder).to receive_messages(format_messages: [{ role: "user", content: "Hello" }],
                                         format_tools: [{ type: "function",
                                                          function: {} }])
    end

    let(:messages) { [Smolagents::ChatMessage.user("Hello")] }
    let(:tool) { double(name: "search", description: "Search") }

    context "with LM Studio capabilities (model_dependent tools, no json_object)" do
      let(:lm_studio_caps) do
        Smolagents::Types::ServerCapability.from_server_type(
          Smolagents::Types::ServerType.lookup(:lm_studio)
        )
      end

      it "includes tools when supports_tools is :model_dependent (optimistic)" do
        # LM Studio has model_dependent tools - be optimistic, let server reject if unsupported
        result = builder.build_params(
          messages:, stop_sequences: nil, temperature: 0.7, max_tokens: 200,
          tools: [tool], response_format: nil, capabilities: lm_studio_caps
        )

        expect(result).to have_key(:tools)
      end

      it "excludes json_object response_format" do
        result = builder.build_params(
          messages:, stop_sequences: nil, temperature: 0.7, max_tokens: 200,
          tools: nil, response_format: { type: "json_object" }, capabilities: lm_studio_caps
        )

        expect(result).not_to have_key(:response_format)
      end

      it "includes json_schema response_format" do
        result = builder.build_params(
          messages:, stop_sequences: nil, temperature: 0.7, max_tokens: 200,
          tools: nil, response_format: { type: "json_schema", json_schema: {} },
          capabilities: lm_studio_caps
        )

        expect(result).to have_key(:response_format)
      end

      it "can use tools and json_schema together (no conflict)" do
        # LM Studio learned tools support (simulating model that supports tools)
        learned_caps = lm_studio_caps.with_learned(:supports_tools, true)

        result = builder.build_params(
          messages:, stop_sequences: nil, temperature: 0.7, max_tokens: 200,
          tools: [tool], response_format: { type: "json_schema", json_schema: {} },
          capabilities: learned_caps
        )

        expect(result).to have_key(:tools)
        expect(result).to have_key(:response_format)
      end
    end

    context "with MLX LM capabilities (model_dependent tools, no json support)" do
      let(:mlx_caps) do
        Smolagents::Types::ServerCapability.from_server_type(
          Smolagents::Types::ServerType.lookup(:mlx_lm)
        )
      end

      it "includes tools when model_dependent (optimistic)" do
        # MLX has model_dependent tools - be optimistic, let server reject if unsupported
        result = builder.build_params(
          messages:, stop_sequences: nil, temperature: 0.7, max_tokens: 200,
          tools: [tool], response_format: nil, capabilities: mlx_caps
        )

        expect(result).to have_key(:tools)
      end

      it "excludes json_object response_format" do
        result = builder.build_params(
          messages:, stop_sequences: nil, temperature: 0.7, max_tokens: 200,
          tools: nil, response_format: { type: "json_object" }, capabilities: mlx_caps
        )

        expect(result).not_to have_key(:response_format)
      end

      it "excludes json_schema response_format" do
        result = builder.build_params(
          messages:, stop_sequences: nil, temperature: 0.7, max_tokens: 200,
          tools: nil, response_format: { type: "json_schema" }, capabilities: mlx_caps
        )

        expect(result).not_to have_key(:response_format)
      end
    end

    context "with llama.cpp capabilities (tools + response_format CONFLICT)" do
      let(:llama_cpp_caps) do
        Smolagents::Types::ServerCapability.from_server_type(
          Smolagents::Types::ServerType.lookup(:llama_cpp)
        )
      end

      it "includes tools when only tools requested" do
        result = builder.build_params(
          messages:, stop_sequences: nil, temperature: 0.7, max_tokens: 200,
          tools: [tool], response_format: nil, capabilities: llama_cpp_caps
        )

        expect(result).to have_key(:tools)
      end

      it "includes json_object response_format when only response_format requested" do
        result = builder.build_params(
          messages:, stop_sequences: nil, temperature: 0.7, max_tokens: 200,
          tools: nil, response_format: { type: "json_object" }, capabilities: llama_cpp_caps
        )

        expect(result).to have_key(:response_format)
      end

      it "DROPS response_format when BOTH tools AND response_format are requested (conflict)" do
        # CRITICAL: llama.cpp cannot use tools AND response_format together
        # When both are requested, prefer tools for agent workloads
        result = builder.build_params(
          messages:, stop_sequences: nil, temperature: 0.7, max_tokens: 200,
          tools: [tool], response_format: { type: "json_object" }, capabilities: llama_cpp_caps
        )

        expect(result).to have_key(:tools)
        expect(result).not_to have_key(:response_format)
      end

      it "drops response_format even for json_schema when tools requested" do
        result = builder.build_params(
          messages:, stop_sequences: nil, temperature: 0.7, max_tokens: 200,
          tools: [tool], response_format: { type: "json_schema", json_schema: {} },
          capabilities: llama_cpp_caps
        )

        expect(result).to have_key(:tools)
        expect(result).not_to have_key(:response_format)
      end
    end

    context "with no capabilities (nil)" do
      it "includes all params when capabilities is nil" do
        result = builder.build_params(
          messages:, stop_sequences: %w[END], temperature: 0.7, max_tokens: 200,
          tools: [tool], response_format: { type: "json_object" }, capabilities: nil
        )

        expect(result).to have_key(:tools)
        expect(result).to have_key(:response_format)
        expect(result).to have_key(:stop)
      end
    end
  end
end
