module Smolagents
  # @api public
  # Configuration namespace for smolagents settings.
  #
  # This module provides centralized configuration management for the library,
  # including default values, validators, and the Configuration class.
  #
  # @example Accessing configuration
  #   Smolagents.configure do |config|
  #     config.max_steps = 30
  #     config.log_level = :debug
  #   end
  #
  # @example Accessing defaults
  #   Smolagents::Config::DEFAULTS[:max_steps]  # => 20
  #
  module Config
    # @return [Array<String>] Default Ruby libraries authorized for agent code execution
    AUTHORIZED_IMPORTS = %w[json uri net/http time date set base64].freeze

    # @return [Hash{Symbol => Object}] Default configuration values
    # @option DEFAULTS [Integer] :max_steps (20) Maximum agent execution steps
    # @option DEFAULTS [String, nil] :custom_instructions (nil) Custom agent instructions
    # @option DEFAULTS [Array<String>] :authorized_imports Allowed imports for code execution
    # @option DEFAULTS [Object, nil] :audit_logger (nil) Logger for audit events
    # @option DEFAULTS [Symbol] :log_format (:text) Output format (:text or :json)
    # @option DEFAULTS [Symbol] :log_level (:info) Logging verbosity level
    # @return [Array<Symbol>] Valid search provider identifiers
    SEARCH_PROVIDERS = %i[duckduckgo bing brave google searxng].freeze

    # @return [Integer] Default planning interval when planning is enabled.
    #   Research (Pre-Act paper, arXiv:2505.09970) shows 3-5 step intervals optimal.
    #   - 3 steps: Good for complex tasks requiring frequent re-planning
    #   - 5 steps: Good for straightforward tasks
    DEFAULT_PLANNING_INTERVAL = 3

    DEFAULTS = {
      max_steps: 20,
      custom_instructions: nil,
      authorized_imports: AUTHORIZED_IMPORTS,
      audit_logger: nil,
      log_format: :text,
      log_level: :info,
      search_provider: :duckduckgo,

      # Planning configuration (Pre-Act pattern)
      # Set to nil to disable planning by default, or an integer to enable.
      # Research shows 70% improvement in Action Recall with planning enabled.
      planning_interval: nil,
      planning_templates: nil
    }.freeze
  end
end
