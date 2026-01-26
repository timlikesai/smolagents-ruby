require "spec_helper"

RSpec.describe Smolagents::Tools::SearchTool::Configuration do
  subject(:config) { described_class.new }

  describe "FieldConfig" do
    let(:field_config_class) { Smolagents::Tools::SearchTool::FieldConfig }

    describe ".create" do
      it "creates a FieldConfig with required selector" do
        fc = field_config_class.create(selector: "h3.title")

        expect(fc.selector).to eq("h3.title")
        expect(fc.extract).to eq(:text)
      end

      it "accepts optional parameters" do
        fc = field_config_class.create(
          selector: "a.link",
          extract: :href,
          prefix: "https://example.com",
          suffix: "?source=search",
          nested: "span.url"
        )

        expect(fc.selector).to eq("a.link")
        expect(fc.extract).to eq(:href)
        expect(fc.prefix).to eq("https://example.com")
        expect(fc.suffix).to eq("?source=search")
        expect(fc.nested).to eq("span.url")
      end
    end

    describe "#[]" do
      it "provides hash-like access to fields" do
        fc = field_config_class.create(selector: "div.result", extract: :href)

        expect(fc[:selector]).to eq("div.result")
        expect(fc[:extract]).to eq(:href)
      end
    end

    describe "#deconstruct_keys" do
      it "supports pattern matching" do
        fc = field_config_class.create(selector: "h2", extract: :text)

        matched = case fc
                  in { selector: "h2", extract: :text }
                    true
                  else
                    false
                  end

        expect(matched).to be true
      end
    end
  end

  describe "#initialize" do
    it "sets default values" do
      expect(config.query_param_name).to eq(:q)
      expect(config.parser_type).to eq(:json)
      expect(config.request_method).to eq(:get)
      expect(config.field_mappings).to eq(title: "title", link: "link", description: "description")
    end
  end

  describe "tool metadata" do
    describe "#name" do
      it "sets the tool name" do
        config.name("my_search")

        expect(config.tool_name).to eq("my_search")
      end
    end

    describe "#description" do
      it "sets the tool description" do
        config.description("Search the web")

        expect(config.tool_description).to eq("Search the web")
      end
    end
  end

  describe "endpoint configuration" do
    describe "#endpoint" do
      it "sets a static endpoint URL" do
        config.endpoint("https://api.example.com/search")

        expect(config.endpoint_url).to eq("https://api.example.com/search")
        expect(config.dynamic_endpoint?).to be false
      end

      it "sets a dynamic endpoint block" do
        config.endpoint { |tool| "https://api.example.com/v#{tool.version}" }

        expect(config.endpoint_url).to be_nil
        expect(config.dynamic_endpoint?).to be true
      end
    end
  end

  describe "parser configuration" do
    describe "#parses" do
      it "sets parser type to :json" do
        config.parses(:json)

        expect(config.parser_type).to eq(:json)
      end

      it "sets parser type to :html" do
        config.parses(:html)

        expect(config.parser_type).to eq(:html)
      end

      it "sets parser type to :rss" do
        config.parses(:rss)

        expect(config.parser_type).to eq(:rss)
      end
    end

    describe "#query_param" do
      it "sets the query parameter name" do
        config.query_param(:query)

        expect(config.query_param_name).to eq(:query)
      end
    end

    describe "#query_input_description" do
      it "sets the query description" do
        config.query_input_description("Search term to query")

        expect(config.query_description).to eq("Search term to query")
      end
    end
  end

  describe "API key configuration" do
    describe "#requires_api_key" do
      it "sets the environment variable name" do
        config.requires_api_key("SEARCH_API_KEY")

        expect(config.api_key_env).to eq("SEARCH_API_KEY")
      end
    end

    describe "#api_key_param" do
      it "sets the API key parameter name" do
        config.api_key_param(:key)

        expect(config.api_key_param_name).to eq(:key)
      end
    end
  end

  describe "request configuration" do
    describe "#http_method" do
      it "sets the HTTP method to :post" do
        config.http_method(:post)

        expect(config.request_method).to eq(:post)
      end
    end

    describe "#rate_limit" do
      it "sets the rate limit interval" do
        config.rate_limit(2.0)

        expect(config.rate_limit_interval).to eq(2.0)
      end
    end

    describe "#auth_header" do
      it "configures authentication header with value proc" do
        config.auth_header("Authorization", ->(key) { "Bearer #{key}" })

        expect(config.auth_header_config[:name]).to eq("Authorization")
        expect(config.auth_header_config[:value].call("abc")).to eq("Bearer abc")
      end

      it "uses identity function by default" do
        config.auth_header("X-Api-Key")

        expect(config.auth_header_config[:value].call("secret")).to eq("secret")
      end
    end
  end

  describe "results configuration" do
    describe "#results_path" do
      it "sets the path to navigate nested response" do
        config.results_path("data", "items")

        expect(config.results_path_keys).to eq(%w[data items])
      end

      it "accepts an array" do
        config.results_path(%w[response results])

        expect(config.results_path_keys).to eq(%w[response results])
      end
    end

    describe "#max_results_limit" do
      it "sets the maximum results cap" do
        config.max_results_limit(100)

        expect(config.max_results_cap).to eq(100)
      end
    end

    describe "#results_limit_param" do
      it "sets the limit parameter name" do
        config.results_limit_param(:count)

        expect(config.results_limit_param_name).to eq(:count)
      end
    end

    describe "#field_mapping" do
      it "configures field mappings" do
        config.field_mapping(title: "name", link: "url", description: "snippet")

        expect(config.field_mappings).to eq(title: "name", link: "url", description: "snippet")
      end
    end

    describe "#additional_params" do
      it "sets additional request parameters" do
        config.additional_params(format: "json", version: 2)

        expect(config.additional_params_config).to eq(format: "json", version: 2)
      end
    end
  end

  describe "custom parameters" do
    describe "#required_param" do
      it "registers a required parameter" do
        config.required_param(:cx, env: "GOOGLE_CX", description: "Search engine ID")

        expect(config.required_params[:cx]).to eq(
          env: "GOOGLE_CX", description: "Search engine ID", as_param: nil
        )
      end

      it "supports as_param for renamed parameters" do
        config.required_param(:engine_id, env: "CX", as_param: :cx)

        expect(config.required_params[:engine_id][:as_param]).to eq(:cx)
      end
    end

    describe "#optional_param" do
      it "registers an optional parameter with default" do
        config.optional_param(:safe_search, default: "on", env: "SAFE_SEARCH")

        expect(config.optional_params[:safe_search]).to eq(
          default: "on", env: "SAFE_SEARCH", as_param: nil
        )
      end
    end
  end

  describe "HTML parsing configuration" do
    describe "#strip_html" do
      it "specifies fields to strip HTML from" do
        config.strip_html(:description, :title)

        expect(config.strip_html_fields).to eq(%i[description title])
      end
    end

    describe "#link_builder" do
      it "sets a custom link builder block" do
        config.link_builder { |raw| "https://example.com#{raw["path"]}" }

        expect(config.link_builder_proc).to be_a(Proc)
      end
    end

    describe "#html_results" do
      it "sets the CSS selector for result rows" do
        config.html_results("div.search-result")

        expect(config.html_result_selector).to eq("div.search-result")
      end
    end

    describe "#html_field" do
      it "configures field extraction from HTML" do
        config.html_field(:title, selector: "h2.title", extract: :text)

        fc = config.html_field_configs[:title]
        expect(fc.selector).to eq("h2.title")
        expect(fc.extract).to eq(:text)
      end

      it "accepts a pre-built FieldConfig" do
        fc = Smolagents::Tools::SearchTool::FieldConfig.create(
          selector: "a.link", extract: :href
        )
        config.html_field(:link, fc)

        expect(config.html_field_configs[:link]).to eq(fc)
      end
    end

    describe "#browser_mode" do
      it "enables browser mode" do
        config.browser_mode(enabled: true)

        expect(config.browser_mode_enabled).to be true
      end

      it "defaults to enabled when called without arguments" do
        config.browser_mode

        expect(config.browser_mode_enabled).to be true
      end
    end
  end

  describe "DEFAULTS" do
    it "contains expected default values" do
      defaults = described_class::DEFAULTS

      expect(defaults[:query_param_name]).to eq(:q)
      expect(defaults[:parser_type]).to eq(:json)
      expect(defaults[:request_method]).to eq(:get)
    end
  end
end
