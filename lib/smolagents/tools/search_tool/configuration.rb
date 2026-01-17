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
        def name(value) = @tool_name = value
        def description(value) = @tool_description = value

        def endpoint(value = nil, &block)
          @endpoint_config = block || value
        end

        def endpoint_url = @endpoint_config.is_a?(String) ? @endpoint_config : nil
        def dynamic_endpoint? = @endpoint_config.is_a?(Proc)

        # Parser and query configuration
        def parses(type) = @parser_type = type
        def query_param(param_name) = @query_param_name = param_name
        def query_input_description(value) = @query_description = value

        # API key configuration
        def requires_api_key(env_var) = @api_key_env = env_var
        def api_key_param(param_name) = @api_key_param_name = param_name

        # Request configuration
        def http_method(method) = @request_method = method
        def rate_limit(requests_per_second) = @rate_limit_interval = requests_per_second

        def auth_header(header_name, value_proc = nil)
          @auth_header_config = { name: header_name, value: value_proc || ->(key) { key } }
        end

        # Results configuration
        def results_path(*keys) = @results_path_keys = keys.flatten
        def max_results_limit(limit) = @max_results_cap = limit
        def results_limit_param(param_name) = @results_limit_param_name = param_name

        def field_mapping(title: "title", link: "link", description: "description")
          @field_mappings = { title:, link:, description: }
        end

        def additional_params(params = {})
          @additional_params_config = params
        end

        # Custom parameters
        def required_param(param_name, env: nil, description: nil, as_param: nil)
          @required_params[param_name] = { env:, description: description || param_name.to_s, as_param: }
        end

        def optional_param(param_name, default: nil, env: nil, as_param: nil)
          @optional_params[param_name] = { default:, env:, as_param: }
        end

        # HTML parsing configuration
        def strip_html(*fields) = @strip_html_fields = fields.flatten
        def link_builder(&block) = @link_builder_proc = block
        def html_results(selector) = @html_result_selector = selector

        def html_field(field, config = nil, **)
          @html_field_configs[field] = config || FieldConfig.create(**)
        end

        # Enable browser User-Agent mode to avoid bot detection.
        # Uses a standard Chrome User-Agent instead of the default bot identifier.
        def browser_mode(enabled: true) = @browser_mode_enabled = enabled
      end
    end
  end
end
