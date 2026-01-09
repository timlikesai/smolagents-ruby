# frozen_string_literal: true

module Smolagents
  # Global configuration for smolagents.
  # Provides defaults that can be overridden per-agent.
  #
  # @example Configure globally
  #   Smolagents.configure do |config|
  #     config.custom_instructions = "Always cite sources"
  #     config.max_steps = 15
  #   end
  #
  # @example Override per-agent
  #   agent = Smolagents::CodeAgent.new(
  #     tools: tools,
  #     model: model,
  #     custom_instructions: "Different instructions for this agent"
  #   )
  class Configuration
    # Custom instructions appended to system prompt
    # @return [String, nil]
    attr_accessor :custom_instructions

    # Maximum reasoning steps for agents
    # @return [Integer]
    attr_accessor :max_steps

    # Ruby modules allowed in CodeAgent execution
    # @return [Array<String>]
    attr_accessor :authorized_imports

    # Initialize configuration with defaults.
    def initialize
      @custom_instructions = nil
      @max_steps = 20
      @authorized_imports = CodeAgent::DEFAULT_AUTHORIZED_IMPORTS.dup
    end

    # Reset configuration to defaults.
    #
    # @return [Configuration] self
    def reset!
      initialize
      self
    end

    # Validate configuration values.
    #
    # @raise [ArgumentError] if configuration is invalid
    # @return [Boolean] true if valid
    def validate!
      raise ArgumentError, "max_steps must be positive" if @max_steps && @max_steps <= 0
      raise ArgumentError, "authorized_imports must be an array" unless @authorized_imports.is_a?(Array)

      raise ArgumentError, "custom_instructions too long (max 10,000 chars)" if @custom_instructions && @custom_instructions.length > 10_000

      true
    end
  end

  # Get the global configuration instance.
  #
  # @return [Configuration] global configuration
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Configure smolagents globally.
  #
  # @yield [Configuration] configuration object
  # @return [Configuration] configured instance
  #
  # @example
  #   Smolagents.configure do |config|
  #     config.custom_instructions = "Always be concise"
  #     config.max_steps = 15
  #   end
  def self.configure
    yield(configuration)
    configuration.validate!
    configuration
  end

  # Reset global configuration to defaults.
  #
  # @return [Configuration] reset configuration
  def self.reset_configuration!
    configuration.reset!
  end
end
