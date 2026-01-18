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
    # @return [Integer] Maximum allowed steps for any agent (safety limit)
    MAX_STEPS_LIMIT = 1_000

    # @return [String] Default LM Studio API base URL (without /v1 suffix)
    DEFAULT_LOCAL_BASE_URL = "http://localhost:1234".freeze

    # @return [String] Default LM Studio API endpoint (with /v1 suffix)
    DEFAULT_LOCAL_API_URL = "#{DEFAULT_LOCAL_BASE_URL}/v1".freeze

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

    # Mapping from search provider to tool name
    SEARCH_PROVIDER_TOOLS = {
      duckduckgo: :duckduckgo_search,
      bing: :bing_search,
      brave: :brave_search,
      google: :google_search,
      searxng: :searxng_search
    }.freeze

    DEFAULTS = {
      max_steps: 20,
      custom_instructions: nil,
      authorized_imports: AUTHORIZED_IMPORTS,
      audit_logger: nil,
      log_format: :text,
      log_level: :info,

      # Search provider configuration
      # Set via SMOLAGENTS_SEARCH_PROVIDER env var or configure block
      search_provider: :duckduckgo,
      # SearXNG instance URL (for :searxng provider)
      # Set via SEARXNG_URL env var or configure block
      searxng_url: nil,

      # Planning configuration (Pre-Act pattern)
      # Set to nil to disable planning by default, or an integer to enable.
      # Research shows 70% improvement in Action Recall with planning enabled.
      planning_interval: nil,
      planning_templates: nil,

      # HTTP & Network settings
      http: {
        timeout_seconds: 30,
        ractor_timeout_seconds: 120,
        rate_limit_status_codes: [429].freeze,
        unavailable_status_codes: [503, 502, 504].freeze,
        retriable_status_codes: [408, 429, 500, 502, 503, 504].freeze,
        max_model_id_length: 64
      }.freeze,

      # Execution & Resource Limits
      execution: {
        max_operations: 100_000,
        max_output_length: 50_000,
        max_message_iterations: 10_000,
        max_queue_iterations: 10_000,
        default_queue_depth: 100
      }.freeze,

      # Isolation & Sandboxing
      isolation: {
        default_timeout_seconds: 5.0,
        default_max_memory_bytes: 50 * 1024 * 1024,
        default_max_output_bytes: 50 * 1024,
        max_ast_depth: 100,
        max_serialization_depth: 100
      }.freeze,

      # Memory & Token estimation
      memory: {
        chars_per_token: 4,
        max_reflections: 10
      }.freeze,

      # Model defaults (per-provider)
      models: {
        openai: { default_max_tokens: 8192 }.freeze,
        anthropic: { default_max_tokens: 4096 }.freeze
      }.freeze,

      # Agent behavior
      agents: {
        refinement_max_iterations: 3,
        refinement_feedback_source: :execution
      }.freeze,

      # Security settings
      security: {
        max_prompt_length: 5000,
        max_validation_errors: 3
      }.freeze,

      # Health check thresholds (ms)
      health: {
        healthy_latency_ms: 1000,
        degraded_latency_ms: 5000,
        timeout_ms: 10_000
      }.freeze
    }.freeze

    # Helper for accessing nested defaults.
    #
    # @example
    #   Config.default(:http, :timeout_seconds)  #=> 30
    #   Config.default(:execution, :max_operations)  #=> 100_000
    #
    # @param keys [Array<Symbol>] Path to the default value
    # @return [Object, nil] The default value or nil if not found
    def self.default(*keys)
      keys.reduce(DEFAULTS) { |hash, key| hash.is_a?(Hash) ? hash[key] : nil }
    end

    # Get all defaults for a category.
    #
    # @param category [Symbol] Category name (e.g., :http, :execution)
    # @return [Hash, nil] The category defaults
    def self.defaults_for(category) = DEFAULTS[category]
  end
end
