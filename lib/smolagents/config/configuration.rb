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
    def reset! = Config::DEFAULTS.each { |k, v| instance_variable_set(:"@#{k}", v.dup) } && (@frozen = false) && self
    def validate! = Config::VALIDATORS.each { |k, v| v.call(instance_variable_get(:"@#{k}")) } && true
  end

  class << self
    def configuration = @configuration ||= Configuration.new
    def configure = yield(configuration) && configuration
    def reset_configuration! = configuration.reset!
    def audit_logger = configuration.audit_logger
  end
end
