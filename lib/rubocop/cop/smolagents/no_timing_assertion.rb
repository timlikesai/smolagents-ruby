# Custom RuboCop cop to enforce meaningful timing tests
# Assertions like `be >= 0` on duration values test nothing useful

module RuboCop
  module Cop
    module Smolagents
      # Forbids meaningless timing assertions in specs.
      #
      # Assertions like `expect(duration).to be >= 0` test nothing useful -
      # a duration is always >= 0. These indicate timing-dependent tests
      # that should instead use:
      # - Explicit times to test calculation logic
      # - Structural verification (type checks)
      #
      # @example Bad - Meaningless assertion
      #   expect(result.duration).to be >= 0
      #   expect(timing.duration).to be > 0
      #   expect(elapsed).to be >= 0
      #
      # @example Good - Test calculation with explicit times
      #   start_time = Time.now
      #   timing = Timing.new(start_time: start_time, end_time: start_time + 2.5)
      #   expect(timing.duration).to eq(2.5)
      #
      # @example Good - Structural verification
      #   expect(result.timing).to be_a(Timing)
      #   expect(result.timing.duration).to be_a(Float)
      #
      class NoTimingAssertion < Base
        MSG = "Avoid `be >= 0` or `be > 0` on duration/timing values - this tests nothing. " \
              "Use explicit times to test calculation: `Timing.new(start_time: t, end_time: t + 2.5)` " \
              "then `expect(timing.duration).to eq(2.5)`. Or verify structure: `be_a(Float)`.".freeze

        # AST pattern for: expect(...).to be >= 0 or expect(...).to be > 0
        # Structure: (send (send nil :expect ...) :to (send (send nil :be) {:>= :>} (int 0)))
        #
        # @!method timing_comparison_to_zero?(node)
        def_node_matcher :timing_comparison_to_zero?, <<~PATTERN
          (send
            (send nil? :expect $_expect_arg)
            :to
            (send
              (send nil? :be)
              ${:>= :>}
              (int ${0 1})))
        PATTERN

        def on_send(node)
          timing_comparison_to_zero?(node) do |expect_arg, _operator, _value|
            # Check if the expect() argument involves duration/timing/elapsed
            return unless timing_related?(expect_arg)

            add_offense(node)
          end
        end

        private

        def timing_related?(node)
          return false unless node

          source = node.source.downcase
          source.include?("duration") || source.include?("timing") || source.include?("elapsed")
        end
      end
    end
  end
end
