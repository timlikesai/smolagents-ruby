module Smolagents
  module Testing
    # Composable validator combinators for testing agent outputs.
    #
    # Validators are lambdas that take an output and return true/false (or a float for partial).
    # They can be composed using combinators like all_of, any_of, none_of, and partial.
    #
    # @example Atomic validators
    #   validator = Validators.contains("Ruby")
    #   validator.call("I found Ruby 4.0")  #=> true
    #
    # @example Combining validators
    #   validator = Validators.all_of(
    #     Validators.contains("Ruby"),
    #     Validators.matches(/\d+\.\d+/)
    #   )
    #   validator.call("Ruby 4.0 is great")  #=> true
    #
    # @example Partial matching
    #   validator = Validators.partial(
    #     Validators.contains("Ruby"),
    #     Validators.contains("Python"),
    #     Validators.contains("Go")
    #   )
    #   validator.call("Ruby and Go are fast")  #=> 0.666...
    #
    # @see Matchers RSpec matchers for agents
    module Validators
      extend self

      # Returns true if output contains the given text.
      #
      # @param text [String] text to search for
      # @return [Proc] validator lambda
      def contains(text) = ->(out) { out.to_s.include?(text) }

      # Returns true if output matches the given regex.
      #
      # @param regex [Regexp] pattern to match
      # @return [Proc] validator lambda
      def matches(regex) = ->(out) { regex.match?(out.to_s) }

      # Returns true if output equals the expected value (after strip).
      #
      # @param expected [String] expected value
      # @return [Proc] validator lambda
      def equals(expected) = ->(out) { out.to_s.strip == expected.to_s.strip }

      # Returns true if extracted number equals expected within tolerance.
      #
      # @param number [Numeric] expected number
      # @param tolerance [Float] allowed difference (default 0.01)
      # @return [Proc] validator lambda
      def numeric_equals(number, tolerance: 0.01)
        ->(out) { (extract_number(out) - number).abs <= tolerance }
      end

      # Returns true if output contains a code block.
      #
      # @return [Proc] validator lambda
      def code_block? = ->(out) { out.to_s.match?(/```(?:ruby)?\n.+?```/m) }

      # Returns true if output contains a tool call to the given tool.
      #
      # @param name [String, Symbol] tool name
      # @return [Proc] validator lambda
      def calls_tool(name) = ->(out) { out.to_s.include?("#{name}(") }

      # Returns true if all validators pass.
      #
      # @param validators [Array<Proc>] validators to combine
      # @return [Proc] validator lambda
      def all_of(*validators) = ->(out) { validators.all? { |v| v.call(out) } }

      # Returns true if any validator passes.
      #
      # @param validators [Array<Proc>] validators to combine
      # @return [Proc] validator lambda
      def any_of(*validators) = ->(out) { validators.any? { |v| v.call(out) } }

      # Returns true if no validators pass.
      #
      # @param validators [Array<Proc>] validators to combine
      # @return [Proc] validator lambda
      def none_of(*validators) = ->(out) { validators.none? { |v| v.call(out) } }

      # Returns the fraction of validators that pass.
      #
      # @param validators [Array<Proc>] validators to combine
      # @return [Proc] validator lambda returning Float
      def partial(*validators)
        ->(out) { validators.count { |v| v.call(out) }.to_f / validators.size }
      end

      private

      def extract_number(text)
        text.to_s.scan(/-?\d+\.?\d*/).first.to_f
      end
    end
  end
end
