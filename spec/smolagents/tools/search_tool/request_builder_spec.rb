require "spec_helper"

RSpec.describe Smolagents::Tools::SearchTool::RequestBuilder do
  let(:test_search_class) do
    Class.new(Smolagents::Tools::SearchTool) do
      configure do |c|
        c.name "test_search"
        c.description "Test search tool"
        c.endpoint "https://api.example.com/search"
        c.parses :json
        c.query_param :q
        c.results_path "results"
        c.field_mapping title: "title", link: "url", description: "snippet"
      end
    end
  end

  let(:tool) { test_search_class.new }

  before do
    stub_request(:get, /api\.example\.com/).to_return(
      status: 200,
      body: { results: [] }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  describe "#make_request" do
    it "performs a GET request by default" do
      tool.execute(query: "test")

      expect(WebMock).to have_requested(:get, "https://api.example.com/search")
        .with(query: hash_including(q: "test"))
    end

    context "with POST method configured" do
      let(:post_search_class) do
        Class.new(Smolagents::Tools::SearchTool) do
          configure do |c|
            c.name "post_search"
            c.description "POST search tool"
            c.endpoint "https://api.example.com/search"
            c.parses :json
            c.http_method :post
            c.query_param :query
            c.results_path "results"
          end
        end
      end

      let(:tool) { post_search_class.new }

      before do
        stub_request(:post, /api\.example\.com/).to_return(
          status: 200,
          body: { results: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end

      it "performs a POST request" do
        tool.execute(query: "test")

        expect(WebMock).to have_requested(:post, "https://api.example.com/search")
      end
    end
  end

  describe "#endpoint" do
    context "with static endpoint" do
      it "returns the configured URL" do
        tool.execute(query: "test")

        expect(WebMock).to have_requested(:get, "https://api.example.com/search")
          .with(query: hash_including(q: "test"))
      end
    end

    context "with dynamic endpoint" do
      let(:dynamic_search_class) do
        Class.new(Smolagents::Tools::SearchTool) do
          configure do |c|
            c.name "dynamic_search"
            c.description "Dynamic endpoint search"
            c.endpoint { |_tool| "https://api.example.com/v2/search" }
            c.parses :json
            c.results_path "results"
          end
        end
      end

      let(:tool) { dynamic_search_class.new }

      before do
        stub_request(:get, %r{api\.example\.com/v2}).to_return(
          status: 200,
          body: { results: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end

      it "evaluates the endpoint block" do
        tool.execute(query: "test")

        expect(WebMock).to have_requested(:get, %r{api\.example\.com/v2/search})
      end
    end
  end

  describe "parameter building" do
    context "with additional params" do
      let(:params_search_class) do
        Class.new(Smolagents::Tools::SearchTool) do
          configure do |c|
            c.name "params_search"
            c.description "Search with params"
            c.endpoint "https://api.example.com/search"
            c.parses :json
            c.additional_params(format: "json", v: "1.0")
            c.results_path "results"
          end
        end
      end

      let(:tool) { params_search_class.new }

      it "includes additional parameters in request" do
        tool.execute(query: "test")

        expect(WebMock).to have_requested(:get, "https://api.example.com/search")
          .with(query: hash_including(format: "json", v: "1.0"))
      end
    end

    context "with results limit param" do
      let(:limit_search_class) do
        Class.new(Smolagents::Tools::SearchTool) do
          configure do |c|
            c.name "limit_search"
            c.description "Search with limit"
            c.endpoint "https://api.example.com/search"
            c.parses :json
            c.results_limit_param :count
            c.results_path "results"
          end
        end
      end

      let(:tool) { limit_search_class.new(max_results: 5) }

      it "includes the limit parameter" do
        tool.execute(query: "test")

        expect(WebMock).to have_requested(:get, "https://api.example.com/search")
          .with(query: hash_including("count" => "5"))
      end
    end

    context "with API key param" do
      let(:api_key_search_class) do
        Class.new(Smolagents::Tools::SearchTool) do
          configure do |c|
            c.name "api_search"
            c.description "Search with API key"
            c.endpoint "https://api.example.com/search"
            c.parses :json
            c.requires_api_key "TEST_API_KEY"
            c.api_key_param :key
            c.results_path "results"
          end
        end
      end

      let(:tool) { api_key_search_class.new(api_key: "secret123") }

      it "includes the API key parameter" do
        tool.execute(query: "test")

        expect(WebMock).to have_requested(:get, "https://api.example.com/search")
          .with(query: hash_including(key: "secret123"))
      end
    end
  end

  describe "header building" do
    context "with auth header" do
      let(:auth_search_class) do
        Class.new(Smolagents::Tools::SearchTool) do
          configure do |c|
            c.name "auth_search"
            c.description "Search with auth header"
            c.endpoint "https://api.example.com/search"
            c.parses :json
            c.requires_api_key "TEST_API_KEY"
            c.auth_header("Authorization", ->(key) { "Bearer #{key}" })
            c.results_path "results"
          end
        end
      end

      let(:tool) { auth_search_class.new(api_key: "mytoken") }

      it "includes the authorization header" do
        tool.execute(query: "test")

        expect(WebMock).to have_requested(:get, %r{api\.example\.com/search})
          .with(headers: { "Authorization" => "Bearer mytoken" })
      end
    end
  end
end
