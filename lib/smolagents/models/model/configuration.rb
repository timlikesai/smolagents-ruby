module Smolagents
  module Models
    class Model
      # Configuration initialization for Model instances.
      #
      # Handles both config-based and keyword-based initialization patterns,
      # extracting model settings into instance variables.
      module Configuration
        KNOWN_PARAMS = %i[model_id api_key api_base temperature max_tokens config].freeze

        TOOL_CALLING_MODES = %i[code native auto].freeze

        def self.included(base)
          base.attr_accessor :logger
          base.attr_reader :model_id, :config, :temperature, :max_tokens, :tool_calling_mode
        end

        private

        def initialize_configuration(config: nil, **params)
          config ? init_from_config(config) : init_from_params(params)
          @tool_calling_mode = resolve_tool_calling_mode(@tool_calling_mode || :code)
          @logger = nil
        end

        def init_from_config(config)
          @config = config
          @model_id = config.model_id
          @api_key = config.api_key
          @api_base = config.api_base
          @temperature = config.temperature
          @max_tokens = config.max_tokens
          @kwargs = config.extras || {}
        end

        def init_from_params(params)
          @config = nil
          @model_id = params[:model_id]
          @api_key = params[:api_key]
          @api_base = params[:api_base]
          @temperature = params.fetch(:temperature, 0.7)
          @max_tokens = params[:max_tokens]
          @tool_calling_mode = params[:tool_calling_mode]
          @kwargs = params.except(*KNOWN_PARAMS, :tool_calling_mode)
        end

        def resolve_tool_calling_mode(mode)
          mode&.to_sym.then { |m| TOOL_CALLING_MODES.include?(m) ? m : :code }
        end
      end
    end
  end
end
