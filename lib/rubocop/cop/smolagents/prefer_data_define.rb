# Custom RuboCop cop to prefer Data.define over Struct.new
# Data.define is immutable by default, which aligns with Ruby 4.0 idioms

module RuboCop
  module Cop
    module Smolagents
      # Enforces using Data.define instead of Struct.new for value objects.
      #
      # Data.define (Ruby 3.2+) creates immutable value objects with:
      # - Frozen instances by default
      # - Pattern matching support
      # - Keyword argument constructors
      # - Value-based equality
      #
      # Struct.new creates mutable objects which can lead to bugs.
      #
      # @example Bad
      #   Point = Struct.new(:x, :y)
      #   Person = Struct.new(:name, :age, keyword_init: true)
      #
      # @example Good
      #   Point = Data.define(:x, :y)
      #   Person = Data.define(:name, :age)
      #
      # @example Good - with methods
      #   Point = Data.define(:x, :y) do
      #     def distance_from_origin
      #       Math.sqrt(x**2 + y**2)
      #     end
      #   end
      #
      class PreferDataDefine < Base
        extend AutoCorrector

        MSG = "Prefer `Data.define` over `Struct.new` for immutable value objects. " \
              "Data.define creates frozen instances with pattern matching support.".freeze

        RESTRICT_ON_SEND = %i[new].freeze

        # @!method struct_new?(node)
        def_node_matcher :struct_new?, <<~PATTERN
          (send (const {nil? (cbase)} :Struct) :new ...)
        PATTERN

        def on_send(node)
          return unless struct_new?(node)

          add_offense(node) do |corrector|
            corrector.replace(node.receiver.loc.expression, "Data")
            corrector.replace(node.loc.selector, "define")

            # Remove keyword_init: true argument if present (Data.define doesn't need it)
            remove_keyword_init_arg(corrector, node)
          end
        end

        private

        def remove_keyword_init_arg(corrector, node)
          node.arguments.each do |arg|
            next unless arg.hash_type?

            arg.pairs.each do |pair|
              if pair.key.sym_type? && pair.key.value == :keyword_init
                # Remove the entire hash if it's the only pair
                if arg.pairs.size == 1
                  # Remove the comma before the hash if there are symbol args
                  if node.arguments.size > 1
                    prev_arg = node.arguments[-2]
                    range = prev_arg.loc.expression.end.join(arg.loc.expression.end)
                    corrector.remove(range)
                  else
                    corrector.remove(arg.loc.expression)
                  end
                else
                  # Remove just this pair
                  corrector.remove(pair.loc.expression)
                end
              end
            end
          end
        end
      end
    end
  end
end
