module Smolagents
  module Tools
    class SearchTool < Tool
      # Immutable configuration for HTML field extraction.
      #
      # Encapsulates all options for extracting a field from HTML search results,
      # including CSS selectors, extraction method, and optional affixes.
      #
      # @example Creating with factory method
      #   config = FieldConfig.create(selector: "a.link", extract: :href)
      #
      # @example Pattern matching
      #   case config
      #   in FieldConfig[selector:, extract: :text]
      #     # handle text extraction
      #   end
      #
      # @see Configuration#html_field For DSL usage
      FieldConfig = Data.define(:selector, :extract, :prefix, :suffix, :nested) do
        # Creates a FieldConfig with defaults for optional fields.
        #
        # @param selector [String] CSS selector to locate the element
        # @param extract [Symbol] Extraction type (:text, :href, :src, or attribute name)
        # @param prefix [String, nil] Prefix to prepend to extracted value
        # @param suffix [String, nil] Suffix to append to extracted value
        # @param nested [String, nil] Additional CSS selector for nested element
        # @return [FieldConfig] New immutable config
        def self.create(selector:, extract: :text, prefix: nil, suffix: nil, nested: nil)
          new(selector:, extract:, prefix:, suffix:, nested:)
        end

        # Hash-like access for compatibility with ResponseParser.
        #
        # @param key [Symbol] Field name to access
        # @return [Object] The field value
        def [](key) = public_send(key)

        # Pattern matching support.
        #
        # @return [Hash] All fields as a hash
        def deconstruct_keys(_) = { selector:, extract:, prefix:, suffix:, nested: }
      end

      # Configuration holder for search tool DSL.
      #
      # Manages all configuration for a search tool, including endpoint,
      # response parsing, field mapping, and API authentication.
      #
      # @see SearchTool For the configure DSL that uses this class
      class Configuration
        attr_reader :tool_name, :tool_description, :endpoint_config, :parser_type,
                    :api_key_env, :rate_limit_interval, :query_param_name,
                    :results_path_keys, :field_mappings, :auth_header_config,
                    :query_description, :additional_params_config, :max_results_cap,
                    :required_params, :optional_params, :results_limit_param_name,
                    :api_key_param_name, :request_method, :strip_html_fields,
                    :link_builder_proc, :html_result_selector, :html_field_configs,
                    :browser_mode_enabled

        DEFAULTS = {
          query_param_name: :q, parser_type: :json, request_method: :get,
          field_mappings: { title: "title", link: "link", description: "description" }.freeze,
          results_path_keys: [], additional_params_config: {}, required_params: {},
          optional_params: {}, strip_html_fields: [], html_field_configs: {}
        }.freeze

        def initialize
          @query_param_name = DEFAULTS[:query_param_name]
          @parser_type = DEFAULTS[:parser_type]
          @request_method = DEFAULTS[:request_method]
          @field_mappings = DEFAULTS[:field_mappings].dup
          @results_path_keys = DEFAULTS[:results_path_keys].dup
          @additional_params_config = DEFAULTS[:additional_params_config].dup
          @required_params = DEFAULTS[:required_params].dup
          @optional_params = DEFAULTS[:optional_params].dup
          @strip_html_fields = DEFAULTS[:strip_html_fields].dup
          @html_field_configs = DEFAULTS[:html_field_configs].dup
        end

        # Tool metadata setters

        # Sets the tool name.
        #
        # @param value [String] Tool name
        # @return [String] The name that was set
        def name(value) = @tool_name = value

        # Sets the tool description.
        #
        # @param value [String] Tool description
        # @return [String] The description that was set
        def description(value) = @tool_description = value

        # Sets the API endpoint (static string or dynamic block).
        #
        # @param value [String, nil] Static endpoint URL
        # @yield Dynamic endpoint block evaluated at request time
        # @return [String, Proc] The endpoint configuration
        def endpoint(value = nil, &block)
          @endpoint_config = block || value
        end

        # Returns the static endpoint URL if configured.
        #
        # @return [String, nil] Static endpoint URL or nil
        def endpoint_url = @endpoint_config.is_a?(String) ? @endpoint_config : nil

        # Checks if endpoint is dynamically computed.
        #
        # @return [Boolean] True if endpoint is a Proc
        def dynamic_endpoint? = @endpoint_config.is_a?(Proc)

        # Parser and query configuration

        # Sets the response parser type.
        #
        # @param type [Symbol] Parser type (:json, :html, :xml, :rss, :atom)
        # @return [Symbol] The parser type
        def parses(type) = @parser_type = type

        # Sets the query parameter name.
        #
        # @param param_name [Symbol, String] Parameter name for query
        # @return [Symbol, String] The parameter name
        def query_param(param_name) = @query_param_name = param_name

        # Sets the description for the query input parameter.
        #
        # @param value [String] Description of what the query parameter expects
        # @return [String] The description
        def query_input_description(value) = @query_description = value

        # API key configuration

        # Sets the environment variable for API key.
        #
        # @param env_var [String] Environment variable name
        # @return [String] The environment variable
        def requires_api_key(env_var) = @api_key_env = env_var

        # Sets the API key parameter name in requests.
        #
        # @param param_name [Symbol, String] Parameter name for API key
        # @return [Symbol, String] The parameter name
        def api_key_param(param_name) = @api_key_param_name = param_name

        # Request configuration

        # Sets the HTTP method for requests.
        #
        # @param method [Symbol] HTTP method (:get, :post)
        # @return [Symbol] The method
        def http_method(method) = @request_method = method

        # Sets the rate limit for requests.
        #
        # @param requests_per_second [Float] Maximum requests per second
        # @return [Float] The rate limit interval
        def rate_limit(requests_per_second) = @rate_limit_interval = requests_per_second

        # Configures authentication header.
        #
        # @param header_name [String] Header name (e.g., "Authorization")
        # @param value_proc [Proc, nil] Block to format API key into header value
        # @return [Hash] The auth header config
        def auth_header(header_name, value_proc = nil)
          @auth_header_config = { name: header_name, value: value_proc || ->(key) { key } }
        end

        # Results configuration

        # Sets the path to reach results in nested API responses.
        #
        # @param keys [*String, Symbol] Keys to navigate nested structure
        # @return [Array] The path keys
        def results_path(*keys) = @results_path_keys = keys.flatten

        # Sets the maximum number of results supported by the API.
        #
        # @param limit [Integer] Maximum results cap
        # @return [Integer] The limit
        def max_results_limit(limit) = @max_results_cap = limit

        # Sets the parameter name for limiting results count.
        #
        # @param param_name [Symbol, String] Parameter name (e.g., :limit, :count)
        # @return [Symbol, String] The parameter name
        def results_limit_param(param_name) = @results_limit_param_name = param_name

        # Configures field name mappings.
        #
        # @param title [String] API field name for title
        # @param link [String] API field name for link
        # @param description [String] API field name for description
        # @return [Hash] The field mappings
        def field_mapping(title: "title", link: "link", description: "description")
          @field_mappings = { title:, link:, description: }
        end

        # Adds additional static parameters to every request.
        #
        # @param params [Hash] Additional parameters
        # @return [Hash] The additional parameters
        def additional_params(params = {})
          @additional_params_config = params
        end

        # Custom parameters

        # Registers a required custom parameter.
        #
        # @param param_name [Symbol] Parameter name
        # @param env [String, nil] Environment variable to read from
        # @param description [String, nil] Parameter description
        # @param as_param [Symbol, nil] API parameter name if different
        # @return [Hash] The parameter config
        def required_param(param_name, env: nil, description: nil, as_param: nil)
          @required_params[param_name] = { env:, description: description || param_name.to_s, as_param: }
        end

        # Registers an optional custom parameter.
        #
        # @param param_name [Symbol] Parameter name
        # @param default [Object] Default value if not provided
        # @param env [String, nil] Environment variable to read from
        # @param as_param [Symbol, nil] API parameter name if different
        # @return [Hash] The parameter config
        def optional_param(param_name, default: nil, env: nil, as_param: nil)
          @optional_params[param_name] = { default:, env:, as_param: }
        end

        # HTML parsing configuration

        # Specifies which result fields should have HTML tags stripped.
        #
        # @param fields [*String, Symbol] Field names to strip HTML from
        # @return [Array] The fields to strip
        def strip_html(*fields) = @strip_html_fields = fields.flatten

        # Sets a custom block to build links from raw result data.
        #
        # @yield [raw_result] Block to transform raw result into link
        # @return [Proc] The link builder proc
        def link_builder(&block) = @link_builder_proc = block

        # Sets the CSS selector for extracting result rows from HTML.
        #
        # @param selector [String] CSS selector (e.g., "div.result")
        # @return [String] The selector
        def html_results(selector) = @html_result_selector = selector

        # Configures extraction rules for an HTML result field.
        #
        # @param field [Symbol] Field name (e.g., :title, :link)
        # @param config [FieldConfig, nil] Pre-built config or nil
        # @param selector [String] CSS selector to find the element
        # @param extract [Symbol] How to extract (:text, :href, :src, or attribute name)
        # @param prefix [String, nil] Prefix to add to extracted value
        # @param suffix [String, nil] Suffix to add to extracted value
        # @param nested [String, nil] Nested CSS selector within the element
        # @return [FieldConfig] The field config
        def html_field(field, config = nil, **)
          @html_field_configs[field] = config || FieldConfig.create(**)
        end

        # Enables browser User-Agent mode to avoid bot detection.
        #
        # Uses a standard Chrome User-Agent instead of the default bot identifier.
        # @param enabled [Boolean] Whether to enable browser mode
        # @return [Boolean] The enabled state
        def browser_mode(enabled: true) = @browser_mode_enabled = enabled
      end
    end
  end
end
