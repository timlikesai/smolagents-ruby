module Smolagents
  module Runtime
    # Analyzes step trajectories for semantic segmentation.
    #
    # Groups consecutive steps by semantic purpose (search, error recovery, etc.)
    # to enable targeted compression strategies.
    #
    # @see Types::TrajectorySegment The segment data type
    class TrajectoryAnalyzer
      # Label predicates for step classification (order matters: specific first).
      LABELS = {
        search: ->(step) { search_step?(step) },
        error_recovery: ->(step) { error_step?(step) },
        planning: ->(step) { planning_step?(step) },
        tool_execution: ->(step) { tool_execution_step?(step) },
        default: ->(_) { true }
      }.freeze

      def initialize(steps) = @steps = steps

      # Segments steps into labeled chunks based on semantic classification.
      def segment
        return [] if @steps.empty?

        @steps.chunk { |step| classify_step(step) }
              .map { |label, steps| build_segment(steps, label) }
      end

      # Extracts key decision points (tool invocations) from steps.
      def extract_decision_points
        @steps.filter_map do |step|
          next unless step.respond_to?(:tool_calls) && step.tool_calls&.any?

          "Step #{step.step_number}: #{step.tool_calls.map(&:name).join(", ")}"
        end
      end

      # Classifies the overall outcome of a set of steps.
      def classify_outcome(steps)
        return :unknown if steps.empty?

        has_errors = steps.any? { |s| s.respond_to?(:error) && s.error }
        has_success = steps.any? { |s| successful_step?(s) }
        determine_outcome(has_errors, has_success)
      end

      private

      def classify_step(step)
        LABELS.each { |label, pred| return label if label != :default && pred.call(step) }
        :default
      end

      def build_segment(steps, label)
        Types::TrajectorySegment.from_steps(steps, label:, outcome: classify_outcome(steps))
      end

      def determine_outcome(has_errors, has_success)
        return :failure if has_errors && !has_success
        return :partial if has_errors && has_success
        return :success if has_success

        :unknown
      end

      def successful_step?(step) = step.respond_to?(:observations) && step.observations && !step.observations.empty?

      class << self
        def search_step?(step)
          return false unless step.respond_to?(:tool_calls) && step.tool_calls&.any?

          step.tool_calls.any? { |tc| tc.name =~ /search/i }
        end

        def error_step?(step) = step.respond_to?(:error) && !step.error.nil?
        def planning_step?(step) = step.is_a?(Types::PlanningStep)
        def tool_execution_step?(step) = step.respond_to?(:tool_calls) && step.tool_calls&.any? == true
      end
    end
  end
end
