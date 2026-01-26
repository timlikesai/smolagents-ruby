# Custom RuboCop cop to enforce type location
# All Data.define types should be in lib/smolagents/types/

module RuboCop
  module Cop
    module Smolagents
      # Enforces that Data.define types are located in the types/ directory.
      #
      # Domain types should be centralized in lib/smolagents/types/ for:
      # - Easy discovery and navigation
      # - Consistent organization
      # - Clear separation from behavior (concerns)
      # - Type registry for documentation
      #
      # @example Bad - type in concerns file
      #   # lib/smolagents/concerns/agents/my_feature.rb
      #   module Concerns
      #     FeatureResult = Data.define(:status, :value)  # Wrong location!
      #   end
      #
      # @example Good - type in types directory
      #   # lib/smolagents/types/feature_result.rb
      #   module Smolagents
      #     module Types
      #       FeatureResult = Data.define(:status, :value)
      #     end
      #   end
      #
      # @example Good - test double in spec (allowed)
      #   # spec/smolagents/my_feature_spec.rb
      #   TestResult = Data.define(:value)  # OK in specs
      #
      class TypeLocationRule < Base
        MSG = "Move `Data.define` type to `lib/smolagents/types/`. " \
              "Domain types should be centralized for discoverability. " \
              "Test doubles in spec/ are allowed.".freeze

        RESTRICT_ON_SEND = %i[define].freeze

        # @!method data_define?(node)
        def_node_matcher :data_define?, <<~PATTERN
          (send (const {nil? (cbase)} :Data) :define ...)
        PATTERN

        def on_send(node)
          return unless data_define?(node)
          return if allowed_location?
          return if inside_method?(node)

          add_offense(node)
        end

        private

        def allowed_location?
          path = processed_source.file_path
          return true if path.nil?

          # Allow in types/ directory
          return true if path.include?("/types/")

          # Allow in spec/ directory (test doubles)
          return true if path.include?("/spec/")

          # Allow in script/ directory (utilities)
          return true if path.include?("/script/")

          false
        end

        # Data.define inside methods is metaprogramming (dynamic type creation),
        # not a static type definition. This is allowed.
        def inside_method?(node)
          node.each_ancestor.any? { |a| a.def_type? || a.defs_type? || a.block_type? }
        end
      end
    end
  end
end
