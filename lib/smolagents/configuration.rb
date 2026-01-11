# frozen_string_literal: true

module Smolagents
  # Global configuration for smolagents.
  class Configuration
    # Default allowed requires in code execution sandbox
    DEFAULT_AUTHORIZED_IMPORTS = %w[json uri net/http time date set base64].freeze

    attr_reader :custom_instructions, :max_steps, :authorized_imports, :audit_logger, :log_format, :log_level

    def initialize
      @custom_instructions = nil
      @max_steps = 20
      @authorized_imports = DEFAULT_AUTHORIZED_IMPORTS.dup
      @audit_logger = nil
      @log_format = :text
      @log_level = :info
      @frozen = false
    end

    def custom_instructions=(value)
      raise FrozenError, "Configuration is frozen" if @frozen

      @custom_instructions = value
    end

    def max_steps=(value)
      raise FrozenError, "Configuration is frozen" if @frozen

      @max_steps = value
    end

    def authorized_imports=(value)
      raise FrozenError, "Configuration is frozen" if @frozen

      @authorized_imports = value
    end

    def audit_logger=(value)
      raise FrozenError, "Configuration is frozen" if @frozen

      @audit_logger = value
    end

    def log_format=(value)
      raise FrozenError, "Configuration is frozen" if @frozen
      raise ArgumentError, "log_format must be :text or :json" unless %i[text json].include?(value)

      @log_format = value
    end

    def log_level=(value)
      raise FrozenError, "Configuration is frozen" if @frozen
      raise ArgumentError, "log_level must be :debug, :info, :warn, or :error" unless %i[debug info warn error].include?(value)

      @log_level = value
    end

    def freeze!
      @frozen = true
      self
    end

    def frozen? = @frozen

    def reset!
      @custom_instructions = nil
      @max_steps = 20
      @authorized_imports = DEFAULT_AUTHORIZED_IMPORTS.dup
      @audit_logger = nil
      @log_format = :text
      @log_level = :info
      @frozen = false
      self
    end

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
