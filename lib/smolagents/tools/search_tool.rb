require_relative "search_tool/configuration"
require_relative "search_tool/request_builder"
require_relative "search_tool/response_parser"

module Smolagents
  module Tools
    # Base class for search tools with DSL for common patterns.
    #
    # Provides a declarative DSL for defining search tools that reduces
    # boilerplate while maintaining flexibility for custom behavior.
    #
    # @see DuckDuckGoSearchTool Example of HTML parsing
    # @see BraveSearchTool Example with API key (pure DSL)
    class SearchTool < Tool
      include Concerns::Http
      include Concerns::Results
      include RequestBuilder
      include ResponseParser

      class << self
        # DSL configuration block for search tools
        # @yield [config] Configuration block with explicit config parameter
        def configure(&block)
          @search_config ||= Configuration.new
          block&.call(@search_config)
          apply_configuration(@search_config)
        end

        # @api private
        def search_config
          @search_config ||= Configuration.new
        end

        private

        def apply_configuration(config)
          apply_tool_metadata(config)
          include_parser_concern(config.parser_type)
          include_api_concerns if config.api_key_env
          apply_rate_limiting(config.rate_limit_interval)
          include Concerns::Support::BrowserMode if config.browser_mode_enabled
        end

        def apply_tool_metadata(config)
          self.tool_name = config.tool_name if config.tool_name
          self.description = config.tool_description if config.tool_description
          self.inputs = { query: { type: "string", description: config.query_description || "Search query" } }
          self.output_type = "string"
        end

        def include_api_concerns
          include Concerns::Api
          include Concerns::ApiKey
        end

        def apply_rate_limiting(interval)
          return unless interval

          include Concerns::RateLimiter

          rate_limit interval
        end

        def include_parser_concern(parser_type)
          case parser_type
          when :json then include Concerns::Json
          when :html then include Concerns::Html
          when :xml, :rss, :atom then include Concerns::Xml
          end
        end
      end

      def initialize(max_results: 10, api_key: nil, **)
        super()
        setup_custom_params(**)
        @max_results = apply_max_results_cap(max_results)
        setup_api_key(api_key) if config.api_key_env
        setup_browser_mode if config.browser_mode_enabled
      end

      def execute(query:)
        enforce_rate_limit!

        safe_api_call do
          results = fetch_results(query:)
          format_results(results.take(@max_results))
        end
      end

      protected

      attr_reader :max_results

      def fetch_results(query:)
        response = make_request(query)
        require_success!(response)
        parse_response(response.body)
      end

      private

      def config = self.class.search_config

      def setup_custom_params(**kwargs)
        config.required_params.each { |name, opts| setup_param(name, opts, kwargs, required: true) }
        config.optional_params.each { |name, opts| setup_param(name, opts, kwargs, required: false) }
      end

      def setup_param(param_name, opts, kwargs, required:)
        value = kwargs[param_name] || (opts[:env] && ENV.fetch(opts[:env], nil)) || opts[:default]
        validate_required_param(param_name, opts, value) if required
        define_param_accessor(param_name, value)
      end

      def validate_required_param(param_name, opts, value)
        return if value

        raise ArgumentError,
              "Missing required parameter: #{opts[:description]}. Set #{opts[:env]} or pass #{param_name}:"
      end

      def define_param_accessor(param_name, value)
        instance_variable_set(:"@#{param_name}", value)
        define_singleton_method(param_name) { instance_variable_get(:"@#{param_name}") }
      end

      def apply_max_results_cap(requested)
        return requested unless config.max_results_cap

        [requested, config.max_results_cap].min
      end

      def setup_api_key(api_key)
        @api_key = require_api_key(api_key, env_var: config.api_key_env)
      end

      # Hook methods - overridden by concerns when included
      def enforce_rate_limit! = nil
      # NOTE: require_success! comes from Concerns::Http (ResponseHandling)
    end
  end

  # Re-export SearchTool at the Smolagents level.
  SearchTool = Tools::SearchTool
end
