# Custom RuboCop cop to prevent backward compatibility re-export shims

module RuboCop
  module Cop
    module Smolagents
      # Prevents re-export shims that alias types from other modules.
      #
      # Re-export shims like `Foo = Other::Module::Foo` create backward
      # compatibility cruft. In a greenfield project, consumers should
      # require types directly from their canonical location.
      #
      # @example Bad - re-export shim
      #   module Security
      #     SpawnViolation = Types::Security::SpawnViolation  # Don't do this
      #   end
      #
      # @example Good - require from canonical location
      #   require "smolagents/types/security/spawn_violation"
      #   # Use Types::Security::SpawnViolation directly
      #
      class NoReexportShim < Base
        MSG = "Avoid re-export shims. Require types from their canonical " \
              "location in `lib/smolagents/types/` instead.".freeze

        # @!method reexport_shim?(node)
        def_node_matcher :reexport_shim?, <<~PATTERN
          (casgn nil? _ (const (const ...) _))
        PATTERN

        def on_casgn(node)
          return unless reexport_shim?(node)
          return if in_types_directory?

          # Only flag if the right side references Types::
          source = node.children[2].source
          return unless source.include?("Types::")

          add_offense(node)
        end

        private

        def in_types_directory?
          path = processed_source.file_path
          path&.include?("/types/")
        end
      end
    end
  end
end
