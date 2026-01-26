require "securerandom"

module Smolagents
  module Types
    module ControlRequests
      # Configuration for request type generation.
      RequestConfig = Data.define(:fields, :defaults, :freeze, :predicates) do
        def all_fields = [:id] + fields + [:created_at]
      end

      # Builds Data.define request classes from config.
      module RequestBuilder
        def self.build(config)
          Data.define(*config.all_fields) do
            include Request

            define_singleton_method(:request_config) { config }
            define_singleton_method(:create) { |**kwargs| CreateFactory.call(self, kwargs) }
            config.predicates.each { |name, pred| define_method(:"#{name}?") { pred.call(self) } }
          end
        end
      end

      # Factory for creating request instances with defaults and freezing.
      module CreateFactory
        def self.call(klass, kwargs)
          config = klass.request_config
          config.defaults.each { |k, v| kwargs[k] = v unless kwargs.key?(k) }
          config.freeze.each { |f| kwargs[f] = kwargs[f]&.freeze }
          klass.new(id: SecureRandom.uuid, created_at: Time.now, **kwargs)
        end
      end

      # DSL for defining control request types (mirrors Events::DSL).
      module DSL
        def define_request(name, fields:, defaults: {}, freeze: [], predicates: {})
          config = RequestConfig.new(fields:, defaults:, freeze:, predicates:)
          const_set(name, RequestBuilder.build(config))
          define_factory_method(name)
        end

        private

        def define_factory_method(name)
          factory_name = name.to_s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym
          define_singleton_method(factory_name) { |**kwargs| const_get(name).create(**kwargs) }
        end
      end
    end
  end
end
