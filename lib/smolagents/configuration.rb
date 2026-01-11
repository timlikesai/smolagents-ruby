# frozen_string_literal: true

module Smolagents
  # Global configuration for smolagents.
  class Configuration
    # Default allowed requires in code execution sandbox
    DEFAULT_AUTHORIZED_IMPORTS = %w[json uri net/http time date set base64].freeze

    attr_accessor :custom_instructions, :max_steps, :authorized_imports, :audit_logger

    def initialize
      @custom_instructions = nil
      @max_steps = 20
      @authorized_imports = DEFAULT_AUTHORIZED_IMPORTS.dup
      @audit_logger = nil
    end

    def reset! = initialize

    def validate!
      raise ArgumentError, "max_steps must be positive" if @max_steps && @max_steps <= 0
      raise ArgumentError, "authorized_imports must be an array" unless @authorized_imports.is_a?(Array)
      raise ArgumentError, "custom_instructions too long (max 10,000 chars)" if @custom_instructions && @custom_instructions.length > 10_000

      true
    end
  end

  def self.configuration = @configuration ||= Configuration.new

  def self.configure
    yield(configuration)
    configuration.validate!
    configuration
  end

  def self.reset_configuration! = configuration.reset!

  def self.audit_logger = configuration.audit_logger
end
