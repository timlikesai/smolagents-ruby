module Smolagents
  class Configuration
    DEFAULT_AUTHORIZED_IMPORTS = %w[json uri net/http time date set base64].freeze

    DEFAULTS = {
      max_steps: 20,
      custom_instructions: nil,
      authorized_imports: DEFAULT_AUTHORIZED_IMPORTS,
      audit_logger: nil,
      log_format: :text,
      log_level: :info
    }.freeze

    VALIDATORS = {
      log_format: ->(v) { %i[text json].include?(v) or raise ArgumentError, "log_format must be :text or :json" },
      log_level: ->(v) { %i[debug info warn error].include?(v) or raise ArgumentError, "log_level must be :debug, :info, :warn, or :error" },
      max_steps: ->(v) { v.nil? || v.positive? or raise ArgumentError, "max_steps must be positive" },
      custom_instructions: ->(v) { v.nil? || v.length <= 10_000 or raise ArgumentError, "custom_instructions too long (max 10,000 chars)" }
    }.freeze

    attr_reader(*DEFAULTS.keys, :frozen)
    alias frozen? frozen

    def initialize
      reset!
    end

    DEFAULTS.each_key do |attr|
      define_method(:"#{attr}=") do |value|
        raise FrozenError, "Configuration is frozen" if @frozen
        VALIDATORS[attr]&.call(value)
        instance_variable_set(:"@#{attr}", value)
      end
    end

    def freeze! = (@frozen = true) && self
    def reset! = DEFAULTS.each { |k, v| instance_variable_set(:"@#{k}", v.dup) } && (@frozen = false) && self
    def validate! = VALIDATORS.each { |k, v| v.call(instance_variable_get(:"@#{k}")) } && true
  end

  class << self
    def configuration = @configuration ||= Configuration.new
    def configure = yield(configuration) && configuration
    def reset_configuration! = configuration.reset!
    def audit_logger = configuration.audit_logger
  end
end
