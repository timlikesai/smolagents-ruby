module Smolagents
  module Tools
    # Base class for search tools with DSL for common patterns.
    #
    # Provides a declarative DSL for defining search tools that reduces
    # boilerplate while maintaining flexibility for custom behavior.
    #
    # @example Simple search tool (no API key)
    #   class MySearchTool < SearchTool
    #     configure do
    #       name "my_search"
    #       description "Search using MySearch"
    #       endpoint "https://api.mysearch.com/search"
    #       parses :json
    #       results_path %w[data results]
    #       field_mapping title: "name", link: "url", description: "snippet"
    #     end
    #   end
    #
    # @example With API key and rate limiting
    #   class PremiumSearchTool < SearchTool
    #     configure do
    #       name "premium_search"
    #       description "Premium search API"
    #       endpoint "https://api.premium.com/v1/search"
    #       parses :json
    #       requires_api_key "PREMIUM_API_KEY"
    #       rate_limit 2.0
    #       auth_header "Authorization", ->(key) { "Bearer #{key}" }
    #       results_path %w[response items]
    #     end
    #   end
    #
    # @example With dynamic endpoint and additional params
    #   class WikiSearchTool < SearchTool
    #     configure do
    #       name "wiki_search"
    #       description "Search Wikipedia"
    #       endpoint { |tool| "https://#{tool.language}.wikipedia.org/w/api.php" }
    #       parses :json
    #       additional_params action: "query", list: "search", format: "json"
    #       results_path "query", "search"
    #     end
    #
    #     attr_reader :language
    #     def initialize(language: "en", **)
    #       @language = language
    #       super
    #     end
    #   end
    #
    # @example With RSS feed parsing
    #   class FeedSearchTool < SearchTool
    #     configure do
    #       name "feed_search"
    #       description "Search RSS feeds"
    #       endpoint "https://feeds.example.com/search"
    #       parses :rss  # Auto-parses RSS items
    #     end
    #   end
    #
    # @example Field mapping with Procs and HTML cleaning
    #   configure do
    #     field_mapping(
    #       title: "name",
    #       link: ->(r) { "https://example.com/#{r['id']}" },
    #       description: ->(r) { strip_html_tags(r["snippet"]) }
    #     )
    #   end
    #
    # @example With required custom parameter
    #   class CustomSearchTool < SearchTool
    #     configure do
    #       name "custom_search"
    #       required_param :instance_url, env: "CUSTOM_URL"
    #       optional_param :categories, default: "general"
    #     end
    #   end
    #
    # @see DuckDuckGoSearchTool Example of HTML parsing search
    # @see GoogleSearchTool Example with custom parameters
    # @see BraveSearchTool Example with API key and rate limiting (pure DSL)
    class SearchTool < Tool
      include Concerns::Http
      include Concerns::Results

      class << self
        # DSL configuration block for search tools
        # @yield [config] Configuration block with explicit config parameter
        # @yieldparam config [Configuration] The configuration object to customize
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
          # Apply tool metadata
          self.tool_name = config.tool_name if config.tool_name
          self.description = config.tool_description if config.tool_description
          self.inputs = { query: { type: "string", description: config.query_description || "Search query" } }
          self.output_type = "string"

          # Include parser concern based on configuration
          include_parser_concern(config.parser_type)

          # Include API concerns if needed
          if config.api_key_env
            include Concerns::Api
            include Concerns::ApiKey
          end

          # Include rate limiter if configured
          return unless config.rate_limit_interval

          include Concerns::RateLimiter

          rate_limit config.rate_limit_interval
        end

        def include_parser_concern(parser_type)
          case parser_type
          when :json then include Concerns::Json
          when :html then include Concerns::Html
          when :xml, :rss, :atom then include Concerns::Xml
          end
        end
      end

      # Configuration holder for search tool DSL.
      #
      # This class manages all configuration for a search tool, including endpoint,
      # response parsing, field mapping, and API authentication. It's typically used
      # through the SearchTool.configure DSL block.
      #
      # @example Create and configure a search tool
      #   config = Configuration.new
      #   config.name "my_search"
      #   config.endpoint "https://api.example.com/search"
      #   config.parses :json
      #   config.results_path "results"
      #   config.field_mapping title: "name", link: "url", description: "snippet"
      #
      # @see SearchTool For the configure DSL that uses this class
      class Configuration
        # @!attribute [r] tool_name
        #   @return [String, nil] The name of the tool
        # @!attribute [r] tool_description
        #   @return [String, nil] Human-readable description
        # @!attribute [r] endpoint_config
        #   @return [String, Proc, nil] Static URL or Proc for dynamic endpoint
        # @!attribute [r] parser_type
        #   @return [Symbol] Response parser (:json, :html, :xml, :rss, :atom)
        # @!attribute [r] api_key_env
        #   @return [String, nil] Environment variable for API key
        # @!attribute [r] rate_limit_interval
        #   @return [Float, nil] Rate limit in requests per second
        # @!attribute [r] query_param_name
        #   @return [Symbol] Parameter name for search query (default: :q)
        # @!attribute [r] results_path_keys
        #   @return [Array<String>] Path to results in JSON response
        # @!attribute [r] field_mappings
        #   @return [Hash{Symbol => String, Proc}] Map of standard fields to response fields
        # @!attribute [r] auth_header_config
        #   @return [Hash, nil] Auth header configuration with :name and :value keys
        # @!attribute [r] query_description
        #   @return [String, nil] Description of query input parameter
        # @!attribute [r] additional_params_config
        #   @return [Hash] Static parameters added to every request
        # @!attribute [r] max_results_cap
        #   @return [Integer, nil] Hard limit on results from API
        # @!attribute [r] required_params
        #   @return [Hash] Custom required parameters
        # @!attribute [r] optional_params
        #   @return [Hash] Custom optional parameters with defaults
        # @!attribute [r] results_limit_param_name
        #   @return [Symbol, nil] API parameter name for limiting results
        # @!attribute [r] api_key_param_name
        #   @return [Symbol, nil] Parameter name if API key goes in query string
        # @!attribute [r] request_method
        #   @return [Symbol] HTTP method (:get or :post)
        # @!attribute [r] strip_html_fields
        #   @return [Array<Symbol>] Fields to strip HTML tags from
        # @!attribute [r] link_builder_proc
        #   @return [Proc, nil] Custom Proc to build links from results
        # @!attribute [r] html_result_selector
        #   @return [String, nil] CSS selector for result containers in HTML
        # @!attribute [r] html_field_configs
        #   @return [Hash] Configuration for extracting fields from HTML elements
        attr_reader :tool_name, :tool_description, :endpoint_config, :parser_type,
                    :api_key_env, :rate_limit_interval, :query_param_name,
                    :results_path_keys, :field_mappings, :auth_header_config,
                    :query_description, :additional_params_config, :max_results_cap,
                    :required_params, :optional_params, :results_limit_param_name,
                    :api_key_param_name, :request_method, :strip_html_fields,
                    :link_builder_proc, :html_result_selector, :html_field_configs

        # Creates a new Configuration with default values.
        #
        # @example
        #   config = Configuration.new
        #   config.query_param_name  # => :q
        #   config.request_method    # => :get
        def initialize
          @query_param_name = :q
          @parser_type = :json
          @field_mappings = { title: "title", link: "link", description: "description" }
          @results_path_keys = []
          @additional_params_config = {}
          @required_params = {}
          @optional_params = {}
          @results_limit_param_name = nil
          @api_key_param_name = nil
          @request_method = :get
          @strip_html_fields = []
          @link_builder_proc = nil
          @html_result_selector = nil
          @html_field_configs = {}
        end

        # Set the tool name.
        #
        # @param value [String] The tool name (used in agent prompts)
        # @return [String] The set value
        def name(value)
          @tool_name = value
        end

        # Set the tool description.
        #
        # @param value [String] Description of what the tool does
        # @return [String] The set value
        def description(value)
          @tool_description = value
        end

        # Set the search endpoint URL (String or Proc)
        # @param value [String, Proc] Static URL or Proc receiving tool instance
        # @example Static endpoint
        #   endpoint "https://api.example.com/search"
        # @example Dynamic endpoint
        #   endpoint { |tool| "https://#{tool.region}.api.example.com/search" }
        def endpoint(value = nil, &block)
          @endpoint_config = block || value
        end

        # Convenience accessor for static endpoint URL
        def endpoint_url
          @endpoint_config.is_a?(String) ? @endpoint_config : nil
        end

        # Check if endpoint is dynamic (Proc)
        def dynamic_endpoint?
          @endpoint_config.is_a?(Proc)
        end

        # Set the response parser type (:json, :html, :xml, :rss, :atom)
        def parses(type)
          @parser_type = type
        end

        # Set the query parameter name (default: :q).
        #
        # @param param_name [Symbol] Parameter name to use in API requests
        # @return [Symbol] The set value
        # @example
        #   config.query_param :q      # Uses ?q=query in requests
        #   config.query_param :search # Uses ?search=query in requests
        def query_param(param_name)
          @query_param_name = param_name
        end

        # Set the description for the query input.
        #
        # Displayed in agent prompts to help agents understand what to search for.
        #
        # @param value [String] Human-readable description of the query parameter
        # @return [String] The set value
        def query_input_description(value)
          @query_description = value
        end

        # Require an API key from environment.
        #
        # @param env_var [String] Environment variable name containing the API key
        # @return [String] The set value
        # @example
        #   config.requires_api_key "OPENAI_API_KEY"
        def requires_api_key(env_var)
          @api_key_env = env_var
        end

        # Include API key as a query parameter instead of header.
        #
        # By default, API keys are sent via Authorization header. This method
        # configures the tool to include the API key as a query parameter instead.
        #
        # @param param_name [Symbol] Parameter name (e.g., :key, :api_key)
        # @return [Symbol] The set value
        # @example Google PSE uses key parameter
        #   requires_api_key "GOOGLE_API_KEY"
        #   api_key_param :key
        def api_key_param(param_name)
          @api_key_param_name = param_name
        end

        # Set the HTTP method for requests (default: :get).
        #
        # Most search APIs use GET requests, but some use POST.
        #
        # @param method [Symbol] HTTP method (:get or :post)
        # @return [Symbol] The set value
        # @example DuckDuckGo Lite uses POST
        #   http_method :post
        def http_method(method)
          @request_method = method
        end

        # Set rate limit in requests per second.
        #
        # The RateLimiter concern will enforce this limit, preventing
        # the tool from overwhelming the API.
        #
        # @param requests_per_second [Float] Maximum requests per second
        # @return [Float] The set value
        # @example
        #   rate_limit 1.0  # One request per second
        #   rate_limit 0.5  # One request every two seconds
        def rate_limit(requests_per_second)
          @rate_limit_interval = requests_per_second
        end

        # Configure authentication header.
        #
        # @param header_name [String] Header name (e.g., "Authorization")
        # @param value_proc [Proc, nil] Proc that receives api_key and returns header value.
        #   If nil, the API key is used directly as the header value.
        # @return [Hash] The set configuration
        # @example Bearer token header
        #   auth_header "Authorization", ->(key) { "Bearer #{key}" }
        # @example Direct API key header
        #   auth_header "X-API-Key"
        def auth_header(header_name, value_proc = nil)
          @auth_header_config = { name: header_name, value: value_proc || ->(key) { key } }
        end

        # Set the path to results in response (for JSON).
        #
        # For APIs that nest results in a hierarchy, specify the path to navigate
        # to the results array. For example, if the response is:
        # { "data": { "results": [ ... ] } }, use results_path("data", "results").
        #
        # @param keys [Array<String, Symbol>] Keys to navigate the response hierarchy
        # @return [Array] The set path
        # @example Nested results
        #   results_path "data", "results"  # { "data": { "results": [...] } }
        # @example Top-level results
        #   results_path "results"  # { "results": [...] }
        def results_path(*keys)
          @results_path_keys = keys.flatten
        end

        # Map response fields to standard result format.
        #
        # Converts API response fields to the standard Smolagents result fields:
        # :title, :link, :description. Values can be strings (field names),
        # Procs (for transformations), or Arrays (for nested paths).
        #
        # @param title [String, Proc, Array] Source for title field
        # @param link [String, Proc, Array] Source for link field
        # @param description [String, Proc, Array] Source for description field
        # @return [Hash{Symbol => String, Proc, Array}] The set mappings
        # @example Basic mapping
        #   field_mapping title: "name", link: "url", description: "snippet"
        # @example With Procs for transformation
        #   field_mapping(
        #     title: "name",
        #     link: ->(r) { "https://example.com/#{r['id']}" },
        #     description: ->(r) { r["text"]&.strip }
        #   )
        def field_mapping(title: "title", link: "link", description: "description")
          @field_mappings = { title: title, link: link, description: description }
        end

        # Add static parameters to every request.
        #
        # These parameters are included in all API requests and never change.
        # Useful for required static settings like API version or format.
        #
        # @param params [Hash] Static parameters to add to requests
        # @return [Hash] The set parameters
        # @example
        #   additional_params action: "query", format: "json"
        def additional_params(params = {})
          @additional_params_config = params
        end

        # Set maximum results cap (API hard limit).
        #
        # Some APIs have a maximum number of results they can return.
        # Set this to enforce that limit even if the user requests more.
        #
        # @param limit [Integer] Maximum results the API can return
        # @return [Integer] The set limit
        # @example Google PSE maximum
        #   max_results_limit 10
        def max_results_limit(limit)
          @max_results_cap = limit
        end

        # Set the parameter name for limiting results in API requests.
        #
        # Different APIs use different parameter names for result limits.
        # This configures which parameter name to use in the API call.
        #
        # @param param_name [Symbol] Parameter name (e.g., :srlimit, :num, :count)
        # @return [Symbol] The set parameter name
        # @example Wikipedia uses srlimit
        #   results_limit_param :srlimit
        # @example Google PSE uses num
        #   results_limit_param :num
        def results_limit_param(param_name)
          @results_limit_param_name = param_name
        end

        # Declare a required custom parameter.
        #
        # Required parameters must be provided by the tool user via constructor
        # or environment variable. Missing required parameters raise an error.
        #
        # @param param_name [Symbol] Parameter name (tool instance attribute)
        # @param env [String, nil] Environment variable to read if not provided
        # @param description [String, nil] Error message description for missing param
        # @param as_param [Symbol, nil] Include in query with this parameter name
        # @return [Hash] The parameter configuration
        # @example Google CSE ID included as cx parameter
        #   required_param :cse_id, env: "GOOGLE_CSE_ID", as_param: :cx
        def required_param(param_name, env: nil, description: nil, as_param: nil)
          @required_params[param_name] = { env: env, description: description || param_name.to_s, as_param: as_param }
        end

        # Declare an optional custom parameter with default value.
        #
        # Optional parameters have sensible defaults and can be overridden
        # by the tool user or from environment variables.
        #
        # @param param_name [Symbol] Parameter name (tool instance attribute)
        # @param default [Object, nil] Default value if not provided
        # @param env [String, nil] Environment variable to read if not provided
        # @param as_param [Symbol, nil] Include in query with this parameter name
        # @return [Hash] The parameter configuration
        # @example SearXNG categories included in query
        #   optional_param :categories, default: "general", as_param: :categories
        def optional_param(param_name, default: nil, env: nil, as_param: nil)
          @optional_params[param_name] = { default: default, env: env, as_param: as_param }
        end

        # Strip HTML tags from specified result fields.
        #
        # Removes all HTML markup from the specified fields in the results,
        # useful when parsing HTML responses or when results contain embedded HTML.
        #
        # @param fields [Array<Symbol>] Fields to strip HTML from (:title, :link, :description)
        # @return [Array<Symbol>] The set fields
        # @example Strip HTML from description field
        #   strip_html :description
        # @example Strip from multiple fields
        #   strip_html :title, :description
        def strip_html(*fields)
          @strip_html_fields = fields.flatten
        end

        # Build link URLs dynamically from result data.
        #
        # For cases where links aren't directly in the response, use a block
        # to construct them from other fields. The block is evaluated in the
        # tool instance context, so you can access instance variables.
        #
        # @yield [result] Block receiving the raw result hash from the API
        # @yieldreturn [String] The URL to use as the link field
        # @return [Proc] The set link builder
        # @example Wikipedia article URLs
        #   link_builder { |r| "https://#{language}.wikipedia.org/wiki/#{r['title'].tr(' ', '_')}" }
        def link_builder(&block)
          @link_builder_proc = block
        end

        # Set CSS selector for HTML result rows (for HTML parsing).
        #
        # When parsing HTML responses, specify the CSS selector that matches
        # the container elements for each result.
        #
        # @param selector [String] CSS selector for result containers
        # @return [String] The set selector
        # @example DuckDuckGo uses table rows
        #   html_results "tr"
        def html_results(selector)
          @html_result_selector = selector
        end

        # Define how to extract a field from HTML result elements.
        #
        # For HTML-parsed responses, specify the CSS selector and extraction
        # method for each result field. You can extract text, href, src, or
        # any custom attribute value.
        #
        # @param field [Symbol] Field name (:title, :link, :description)
        # @param selector [String] CSS selector within result element
        # @param extract [Symbol] What to extract (:text, :href, :src, or attribute name)
        # @param prefix [String, nil] Prefix to add to extracted value
        # @param suffix [String, nil] Suffix to add to extracted value
        # @param nested [String, nil] Nested selector for extraction (e.g., get text from child element)
        # @return [void]
        # @example DuckDuckGo field extraction
        #   html_field :title, selector: "a.result-link", extract: :text
        #   html_field :link, selector: "span.link-text", extract: :text, prefix: "https://"
        #   html_field :description, selector: "td.result-snippet", extract: :text
        def html_field(field, selector:, extract: :text, prefix: nil, suffix: nil, nested: nil)
          @html_field_configs[field] = {
            selector: selector,
            extract: extract,
            prefix: prefix,
            suffix: suffix,
            nested: nested
          }
        end
      end

      # Initialize with max_results and optional API key
      def initialize(max_results: 10, api_key: nil, **)
        super()
        setup_custom_params(**)
        @max_results = apply_max_results_cap(max_results)
        setup_api_key(api_key) if config.api_key_env
      end

      # Template method for search execution
      def execute(query:)
        enforce_rate_limit!

        safe_api_call do
          results = fetch_results(query: query)
          format_results(results.take(@max_results))
        end
      end

      protected

      # Override this method for custom fetch logic
      # @param query [String] Search query
      # @return [Array<Hash>] Array of result hashes with :title, :link, :description
      def fetch_results(query:)
        response = make_request(query)
        require_success!(response)
        parse_response(response.body)
      end

      # Make HTTP request using configured method (GET or POST)
      def make_request(query)
        params = build_params(query)
        headers = build_headers

        case config.request_method
        when :post
          post(endpoint, form: params, headers: headers)
        else
          get(endpoint, params: params, headers: headers)
        end
      end

      # Access the configured endpoint (resolves dynamic endpoints)
      def endpoint
        if config.dynamic_endpoint?
          config.endpoint_config.call(self)
        else
          config.endpoint_url
        end
      end

      # Access max_results
      attr_reader :max_results

      private

      def config
        self.class.search_config
      end

      def setup_custom_params(**kwargs)
        # Handle required params
        config.required_params.each do |param_name, opts|
          value = kwargs[param_name] || (opts[:env] && ENV.fetch(opts[:env], nil))
          raise ArgumentError, "Missing required parameter: #{opts[:description]}. Set #{opts[:env]} or pass #{param_name}:" unless value

          instance_variable_set(:"@#{param_name}", value)
          define_singleton_method(param_name) { instance_variable_get(:"@#{param_name}") }
        end

        # Handle optional params
        config.optional_params.each do |param_name, opts|
          value = kwargs[param_name] || (opts[:env] && ENV.fetch(opts[:env], nil)) || opts[:default]
          instance_variable_set(:"@#{param_name}", value)
          define_singleton_method(param_name) { instance_variable_get(:"@#{param_name}") }
        end
      end

      def apply_max_results_cap(requested)
        return requested unless config.max_results_cap

        [requested, config.max_results_cap].min
      end

      def setup_api_key(api_key)
        @api_key = require_api_key(api_key, env_var: config.api_key_env)
      end

      def build_params(query)
        params = { config.query_param_name => query }
        params.merge!(config.additional_params_config)
        params[config.results_limit_param_name] = max_results if config.results_limit_param_name

        # Include API key as query param if configured
        params[config.api_key_param_name] = @api_key if config.api_key_param_name && @api_key

        # Include required params with as_param option
        config.required_params.each do |param_name, opts|
          params[opts[:as_param]] = send(param_name) if opts[:as_param]
        end

        # Include optional params with as_param option
        config.optional_params.each do |param_name, opts|
          params[opts[:as_param]] = send(param_name) if opts[:as_param]
        end

        params
      end

      def build_headers
        return {} unless config.auth_header_config && @api_key

        header_name = config.auth_header_config[:name]
        header_value = config.auth_header_config[:value].call(@api_key)
        { header_name => header_value }
      end

      def parse_response(body)
        data = parse_body(body)
        extract_results(data)
      end

      def parse_body(body)
        case config.parser_type
        when :json then parse_json(body)
        when :html then parse_html(body)
        when :xml then parse_xml(body)
        when :rss then parse_rss_items(body, limit: max_results)
        when :atom then parse_atom_entries(body, limit: max_results)
        else body
        end
      end

      def extract_results(data)
        # RSS/Atom parsing already returns result arrays
        return data if %i[rss atom].include?(config.parser_type)

        # HTML parsing with DSL selectors
        return extract_html_results(data) if config.parser_type == :html && config.html_result_selector

        results = if config.results_path_keys.any?
                    data.dig(*config.results_path_keys) || []
                  else
                    data
                  end

        mapped = map_results_with_link_builder(Array(results))
        strip_html_from_results(mapped)
      end

      def extract_html_results(doc)
        results = []

        doc.css(config.html_result_selector).each do |row|
          break if results.size >= max_results

          result = extract_html_fields(row)
          results << result if result_valid?(result)
        end

        strip_html_from_results(results)
      end

      def extract_html_fields(row)
        result = {}

        config.html_field_configs.each do |field, opts|
          element = opts[:nested] ? row.at_css(opts[:selector])&.at_css(opts[:nested]) : row.at_css(opts[:selector])
          next unless element

          value = extract_element_value(element, opts[:extract])
          value = "#{opts[:prefix]}#{value}" if opts[:prefix] && value
          value = "#{value}#{opts[:suffix]}" if opts[:suffix] && value
          result[field] = value&.strip
        end

        result
      end

      def extract_element_value(element, extract_type)
        case extract_type
        when :text then element.text
        when :href then element["href"]
        when :src then element["src"]
        else element[extract_type.to_s]
        end
      end

      def result_valid?(result)
        # Require at least title or link to be present
        result[:title] || result[:link]
      end

      def map_results_with_link_builder(results)
        mapped = map_results(results, **config.field_mappings)

        return mapped unless config.link_builder_proc

        # Apply link builder - evaluate proc in instance context
        results.zip(mapped).map do |raw, result|
          result[:link] = instance_exec(raw, &config.link_builder_proc)
          result
        end
      end

      def strip_html_from_results(results)
        return results if config.strip_html_fields.empty?

        results.map do |result|
          config.strip_html_fields.each do |field|
            result[field] = strip_html_tags(result[field]) if result[field]
          end
          result
        end
      end

      def strip_html_tags(text)
        text.to_s.gsub(/<[^>]*>/, "")
      end

      # Hook methods - overridden by concerns when included
      # RateLimiter overrides this to enforce rate limits
      def enforce_rate_limit! = nil

      # Api concern overrides this to validate response status
      def require_success!(_response) = nil
    end
  end

  # Re-export SearchTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::SearchTool
  SearchTool = Tools::SearchTool
end
