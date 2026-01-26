module Smolagents
  module Concerns
    # Helpers for common concern patterns.
    #
    # Provides utilities for defining composite concerns, conditional includes,
    # and auto-extending class methods. Reduces boilerplate in concern modules.
    #
    # @example Composite concern with sub-modules
    #   module MyComposite
    #     BaseConcern.define_composite(self, SubModuleA, SubModuleB)
    #   end
    #
    # @example Conditional includes
    #   def self.included(base)
    #     BaseConcern.conditionally_include(base, Events::Emitter, Events::Consumer)
    #   end
    #
    # @example Auto-extending ClassMethods
    #   module MyConfig
    #     include BaseConcern::ClassMethodsSupport
    #
    #     module ClassMethods
    #       def config_method(value) = @value = value
    #     end
    #   end
    module BaseConcern
      # Defines composite concern scaffolding for a module.
      #
      # Sets up `included` and optionally `extended` hooks that include/extend
      # all sub-modules into the target class/instance.
      #
      # @param primary_module [Module] The module being defined
      # @param sub_modules [Array<Module>] Modules to include on `included`
      # @param class_methods [Module, nil] Module to extend on inclusion
      # @param conditional [Array<Module>] Modules to conditionally include (skip if already present)
      # @param support_extend [Boolean] Whether to also define `extended` hook (default: false)
      # @return [void]
      #
      # @example Basic composite
      #   BaseConcern.define_composite(self, SubA, SubB)
      #
      # @example With class methods
      #   BaseConcern.define_composite(self, SubA, SubB, class_methods: ClassMethods)
      #
      # @example With conditional includes
      #   BaseConcern.define_composite(self, SubA, conditional: [Events::Emitter])
      def self.define_composite(primary_module, *sub_modules, class_methods: nil, conditional: [],
                                support_extend: false)
        define_included_hook(primary_module, sub_modules, class_methods, conditional)
        define_extended_hook(primary_module, sub_modules, conditional) if support_extend
      end

      def self.define_included_hook(primary_module, sub_modules, class_methods, conditional)
        primary_module.define_singleton_method(:included) do |base|
          conditional.each { |mod| base.include(mod) unless base < mod }
          sub_modules.each { |mod| base.include(mod) }
          base.extend(class_methods) if class_methods
        end
      end

      def self.define_extended_hook(primary_module, sub_modules, conditional)
        primary_module.define_singleton_method(:extended) do |instance|
          conditional.each { |mod| instance.extend(mod) unless instance.singleton_class.include?(mod) }
          sub_modules.each { |mod| instance.extend(mod) }
        end
      end

      private_class_method :define_included_hook, :define_extended_hook

      # Conditionally includes modules only if not already present.
      #
      # Uses `base < Module` check to skip modules that are already ancestors.
      # Useful when multiple concerns may include the same foundational module.
      #
      # @param base [Class, Module] Target to include into
      # @param modules [Array<Module>] Modules to conditionally include
      # @return [void]
      #
      # @example
      #   def self.included(base)
      #     BaseConcern.conditionally_include(base, Events::Emitter, Events::Consumer)
      #     base.include(MyCoreConcern)
      #   end
      def self.conditionally_include(base, *modules)
        modules.each { |mod| base.include(mod) unless base < mod }
      end

      # Conditionally extends modules only if not already present.
      #
      # @param instance [Object] Target instance to extend
      # @param modules [Array<Module>] Modules to conditionally extend
      # @return [void]
      def self.conditionally_extend(instance, *modules)
        modules.each { |mod| instance.extend(mod) unless instance.singleton_class.include?(mod) }
      end

      # Mixin that auto-extends ClassMethods when included.
      #
      # Include this in concerns that define a nested ClassMethods module.
      # The ClassMethods will be automatically extended onto the including class.
      #
      # @example
      #   module MyConfig
      #     include BaseConcern::ClassMethodsSupport
      #
      #     module ClassMethods
      #       def my_dsl_method(value)
      #         @my_value = value
      #       end
      #
      #       def my_value = @my_value
      #     end
      #   end
      #
      #   class MyModel
      #     include MyConfig
      #     my_dsl_method :foo
      #   end
      #
      #   MyModel.my_value #=> :foo
      module ClassMethodsSupport
        def self.included(concern_module)
          concern_module.define_singleton_method(:included) do |base|
            base.extend(const_get(:ClassMethods)) if const_defined?(:ClassMethods)
          end
        end
      end
    end
  end
end
