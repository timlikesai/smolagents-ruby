module Smolagents
  module Routing
    module Strategies
      # Composite strategy combining multiple routing strategies.
      #
      # Combines decisions from multiple strategies using different methods:
      # - :all - All strategies must agree on :execute_directly
      # - :any - Any strategy voting :execute_directly wins
      # - :vote - Majority vote determines outcome
      #
      # @example All strategies must agree
      #   composite = Composite.new(
      #     strategies: [Threshold.new, CostAware.new],
      #     combine_with: :all
      #   )
      #
      # @example Majority vote
      #   composite = Composite.new(
      #     strategies: [s1, s2, s3],
      #     combine_with: :vote
      #   )
      #
      class Composite
        include RoutingStrategy

        def self.strategy_name = :composite

        attr_reader :strategies, :combine_method

        # @param strategies [Array<RoutingStrategy>] Strategies to combine
        # @param combine_with [Symbol] :all, :any, or :vote
        def initialize(strategies:, combine_with: :all)
          @strategies = strategies
          @combine_method = combine_with
        end

        # Routes by combining decisions from all strategies.
        #
        # @param prediction [SpeculativeToolCall] The tool call to route
        # @param context [Hash] Routing context
        # @return [Symbol] :execute_directly, :validate_with_primary, or :delegate_to_primary
        def route(prediction, context)
          decisions = strategies.map { |s| s.route(prediction, context) }
          combine_decisions(decisions)
        end

        private

        def combine_decisions(decisions)
          case combine_method
          when :all then combine_all(decisions)
          when :any then combine_any(decisions)
          when :vote then combine_vote(decisions)
          else
            raise ArgumentError, "Unknown combine method: #{combine_method}"
          end
        end

        def combine_all(decisions)
          decisions.all?(:execute_directly) ? :execute_directly : :validate_with_primary
        end

        def combine_any(decisions)
          decisions.any?(:execute_directly) ? :execute_directly : :validate_with_primary
        end

        def combine_vote(decisions)
          execute_votes = decisions.count(:execute_directly)
          execute_votes > decisions.size / 2 ? :execute_directly : :validate_with_primary
        end
      end
    end
  end
end
