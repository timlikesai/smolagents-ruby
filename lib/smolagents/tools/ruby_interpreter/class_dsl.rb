module Smolagents
  module Tools
    class RubyInterpreterTool < Tool
      # Class-level DSL methods for sandbox configuration.
      #
      # Provides declarative sandbox configuration at the class level,
      # with inheritance support for subclasses.
      #
      # @example Configuring sandbox at class level
      #   class CustomInterpreter < RubyInterpreterTool
      #     sandbox do |config|
      #       config.timeout(60)
      #       config.max_operations(200_000)
      #     end
      #   end
      module ClassDsl
        # DSL block for configuring sandbox settings at the class level.
        #
        # @yield [config] Configuration block with explicit builder parameter
        # @yieldparam config [SandboxConfigBuilder] The sandbox configuration builder
        # @return [SandboxConfig] The sandbox configuration
        def sandbox(&block)
          builder = SandboxConfigBuilder.new
          block&.call(builder)
          @sandbox_config = builder.build
        end

        # Returns the sandbox configuration, inheriting from parent if not set.
        #
        # @return [SandboxConfig] Always returns a SandboxConfig (creates default if needed)
        def sandbox_config
          @sandbox_config ||
            (superclass.sandbox_config if superclass.respond_to?(:sandbox_config)) ||
            SandboxConfigBuilder.new.build
        end
      end
    end
  end
end
