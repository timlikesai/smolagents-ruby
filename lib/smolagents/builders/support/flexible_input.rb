module Smolagents
  module Builders
    module Support
      # Reusable patterns for flexible DSL input handling.
      #
      # Provides helpers for accepting multiple input formats while maintaining
      # clean, consistent builder interfaces. Supports:
      # - Boolean toggles with positional/keyword flexibility
      # - Type-based dispatch for polymorphic positional arguments
      # - Input normalization for common transformations
      #
      # @example Boolean toggle
      #   def evaluation(enabled_arg = UNSET, enabled: nil)
      #     resolved = resolve_boolean(enabled_arg, enabled, default: true)
      #     with_config(evaluation_enabled: resolved)
      #   end
      #
      # @example Type dispatch
      #   def memory(value = UNSET, budget: nil, strategy: nil)
      #     budget, strategy = dispatch_by_type(value, Integer => budget, Symbol => strategy)
      #     # ...
      #   end
      module FlexibleInput
        # Sentinel value indicating no argument was provided.
        UNSET = :_default_

        private

        # Resolve a boolean toggle from positional or keyword argument.
        #
        # Keywords take precedence. Positional accepts true/false/UNSET.
        #
        # @param positional [Boolean, Symbol] Positional argument (true, false, or UNSET)
        # @param keyword [Boolean, nil] Keyword argument (takes precedence if not nil)
        # @param default [Boolean] Default value when UNSET
        # @param name [String] Argument name for error messages
        # @return [Boolean] Resolved boolean value
        def resolve_boolean(positional, keyword, default:, name: "argument")
          return keyword unless keyword.nil?

          case positional
          in :_default_
            default
          in true | false => value
            value
          else
            raise ArgumentError, "Invalid #{name}: #{positional.inspect}. Use true/false."
          end
        end

        # Dispatch a positional argument to keyword slots based on its type.
        #
        # Returns keyword values, with positional overriding the matching type slot.
        # UNSET positional returns all keywords unchanged.
        #
        # @param positional [Object] Positional argument to dispatch
        # @param type_map [Hash{Class => Object}] Maps types to keyword fallback values
        # @param name [String] Argument name for error messages
        # @return [Array] Values in order of type_map keys
        #
        # @example
        #   dispatch_by_type(100, Integer => budget_kw, Symbol => strategy_kw)
        #   #=> [100, strategy_kw]  # Integer matched, overrides budget slot
        def dispatch_by_type(positional, name: "argument", **type_map)
          return type_map.values if positional == UNSET

          type_map.each_key do |type|
            return type_map.merge(type => positional).values if positional.is_a?(type)
          end

          valid = type_map.keys.map(&:name).join(", ")
          raise ArgumentError, "Invalid #{name}: #{positional.inspect}. Use #{valid}."
        end

        # Normalize input to a string, joining arrays with newlines.
        #
        # @param input [String, Array<String>, Object] Input to normalize
        # @param separator [String] Separator for joining arrays
        # @return [String] Normalized string
        def normalize_to_string(input, separator: "\n")
          case input
          when Array then input.join(separator)
          else input.to_s
          end
        end

        # Resolve enable/disable from various input formats.
        #
        # Accepts booleans and common symbol aliases (:enabled, :disabled, :on, :off).
        #
        # @param positional [Boolean, Symbol] Positional argument
        # @param keyword [Boolean, nil] Keyword argument (takes precedence)
        # @param default [Boolean] Default when UNSET
        # @param name [String] Argument name for error messages
        # @return [Boolean] Resolved enabled state
        def resolve_toggle(positional, keyword, default:, name: "argument")
          return keyword unless keyword.nil?

          case positional
          in :_default_
            default
          in true | :enabled | :on
            true
          in false | :disabled | :off | nil
            false
          else
            raise ArgumentError, "Invalid #{name}: #{positional.inspect}. " \
                                 "Use true/false or :enabled/:disabled."
          end
        end

        # Resolve a positional that can be either a value (of specific type) or a toggle.
        #
        # Common pattern for DSL methods like planning(5) vs planning(false).
        #
        # @param positional [Object] Positional argument (value or toggle)
        # @param keyword [Object, nil] Keyword fallback (takes precedence if not nil)
        # @param value_type [Class] Type for direct value (e.g., Integer)
        # @param default [Object] Value when enabled (UNSET or true)
        # @param disabled [Object] Value when disabled (default: nil)
        # @param name [String] Argument name for error messages
        # @return [Object] Resolved value
        def resolve_value_or_toggle(positional, keyword, value_type:, default:, disabled: nil, name: "argument")
          return keyword if keyword

          case positional
          in :_default_ | true | :enabled | :on
            default
          in ^value_type => value
            value
          in false | :disabled | :off | nil
            disabled
          else
            raise ArgumentError, "Invalid #{name}: #{positional.inspect}. " \
                                 "Use #{value_type.name}, true/false, or :enabled/:disabled."
          end
        end
      end
    end
  end
end
