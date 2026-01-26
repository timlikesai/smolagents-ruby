# Custom RuboCop cop to encourage endless methods for simple predicates
# Ruby 3.0+ syntax for cleaner, more expressive code

module RuboCop
  module Cop
    module Smolagents
      # Encourages endless method syntax for simple predicates and accessors.
      #
      # Ruby 3.0+ endless methods (`def foo = expr`) are more concise for
      # single-expression methods, especially predicates (methods ending in ?).
      #
      # This cop only flags methods that are good candidates:
      # - Single expression body
      # - Predicate methods (ending in ?)
      # - Simple comparisons or delegations
      #
      class PreferEndlessMethod < Base
        extend AutoCorrector

        MSG = "Use endless method syntax: `def %<name>s = %<body>s`. " \
              "Endless methods are more concise for single expressions.".freeze

        MAX_LINE_LENGTH = 120

        # AST node types for simple literal values
        SIMPLE_TYPES = %i[ivar lvar str sym int float].freeze
        BOOLEAN_TYPES = %i[true false nil].freeze
        SIMPLE_ARG_TYPES = (SIMPLE_TYPES + BOOLEAN_TYPES + %i[send]).freeze

        def on_def(node)
          return unless single_expression_candidate?(node)
          return if already_endless?(node)
          return if endless_would_exceed_line_length?(node)

          message = format(MSG, name: method_signature(node), body: node.body.source)
          add_offense(node, message:) do |corrector|
            corrector.replace(node, build_endless_method(node))
          end
        end

        private

        def single_expression_candidate?(node)
          return false unless node.body
          return false if node.body.begin_type?
          return false if node.body.source.include?("\n")

          simple_expression?(node.body)
        end

        def simple_expression?(body)
          return true if SIMPLE_TYPES.include?(body.type)
          return true if BOOLEAN_TYPES.include?(body.type)
          return simple_send?(body) if body.type == :send
          return boolean_expression?(body) if %i[and or].include?(body.type)

          false
        end

        def simple_send?(body)
          !body.block_type? && body.children.all? { |c| c.nil? || simple_arg?(c) }
        end

        def boolean_expression?(body) = simple_expression?(body.children[0]) && simple_expression?(body.children[1])

        def simple_arg?(node)
          return true unless node.is_a?(Parser::AST::Node)

          SIMPLE_ARG_TYPES.include?(node.type)
        end

        def already_endless?(node) = !node.body.nil? && !node.loc.end

        def endless_would_exceed_line_length?(node)
          indent = node.loc.column
          endless_length = indent + build_endless_method(node).length
          endless_length > MAX_LINE_LENGTH
        end

        def method_signature(node)
          return node.method_name.to_s if node.arguments.empty?

          args_source = node.arguments.source
          args_source = args_source[1..-2] if args_source.start_with?("(") && args_source.end_with?(")")
          "#{node.method_name}(#{args_source})"
        end

        def build_endless_method(node) = "def #{method_signature(node)} = #{node.body.source}"
      end
    end
  end
end
