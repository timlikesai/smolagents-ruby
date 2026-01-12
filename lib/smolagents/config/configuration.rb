module Smolagents
  class Configuration
    DEFAULT_AUTHORIZED_IMPORTS = Config::AUTHORIZED_IMPORTS

    attr_reader(*Config::DEFAULTS.keys, :frozen)
    alias frozen? frozen

    def initialize = reset!

    Config::DEFAULTS.each_key do |attr|
      define_method(:"#{attr}=") do |value|
        raise FrozenError, "Configuration is frozen" if @frozen

        Config::VALIDATORS[attr]&.call(value)
        instance_variable_set(:"@#{attr}", value)
      end
    end

    def freeze! = (@frozen = true) && self
    def freeze = dup.freeze!

    def reset! = Config::DEFAULTS.each { |key, val| instance_variable_set(:"@#{key}", val.dup) } && (@frozen = false) && self
    def reset = dup.reset!

    def validate! = Config::VALIDATORS.each { |key, validator| validator.call(instance_variable_get(:"@#{key}")) } && true

    def validate
      (validate!
       true)
    rescue StandardError
      false
    end
    alias valid? validate
  end

  class << self
    def configuration = @configuration ||= Configuration.new
    def configure = yield(configuration) && configuration
    def reset_configuration! = configuration.reset!
    def audit_logger = configuration.audit_logger
  end
end
