module Smolagents
  module Tools
    class SearchTool < Tool
      # Builds HTTP requests for search APIs.
      module RequestBuilder
        protected

        def make_request(query)
          params = build_params(query)
          headers = build_headers

          case config.request_method
          when :post
            post(endpoint, form: params, headers:)
          else
            get(endpoint, params:, headers:)
          end
        end

        def endpoint
          if config.dynamic_endpoint?
            config.endpoint_config.call(self)
          else
            config.endpoint_url
          end
        end

        private

        def build_params(query)
          params = { config.query_param_name => query }
          params.merge!(config.additional_params_config)
          add_results_limit(params)
          add_api_key_param(params)
          add_configured_params(params, config.required_params)
          add_configured_params(params, config.optional_params)
          params
        end

        def add_results_limit(params)
          return unless config.results_limit_param_name

          params[config.results_limit_param_name] = max_results
        end

        def add_api_key_param(params)
          return unless config.api_key_param_name && @api_key

          params[config.api_key_param_name] = @api_key
        end

        def add_configured_params(params, param_configs)
          param_configs.each do |param_name, opts|
            params[opts[:as_param]] = send(param_name) if opts[:as_param]
          end
        end

        def build_headers
          headers = browser_headers_if_enabled
          return headers unless config.auth_header_config && @api_key

          header_name = config.auth_header_config[:name]
          header_value = config.auth_header_config[:value].call(@api_key)
          headers.merge(header_name => header_value)
        end

        def browser_headers_if_enabled
          return {} unless defined?(@browser_headers) && @browser_headers

          @browser_headers.dup
        end
      end
    end
  end
end
