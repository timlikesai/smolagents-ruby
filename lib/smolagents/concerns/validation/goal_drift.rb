module Smolagents
  module Concerns
    # Goal Drift Detection for monitoring task adherence.
    #
    # Research shows agents can gradually drift from their original task,
    # especially in multi-step interactions. This concern monitors action
    # sequences and flags when behavior deviates from the goal.
    #
    # @see https://arxiv.org/abs/2505.02709 Goal drift in LLM agents
    #
    # @example Basic usage
    #   include GoalDrift
    #
    #   drift = check_goal_drift(task, recent_steps)
    #   if drift.drifting?
    #     inject_guidance("Refocus on: #{task}")
    #   end
    module GoalDrift
      # Drift severity levels.
      DRIFT_LEVELS = %i[none mild moderate severe].freeze

      # Configuration for drift detection.
      #
      # @!attribute [r] enabled
      #   @return [Boolean] Whether drift detection is enabled
      # @!attribute [r] window_size
      #   @return [Integer] Number of recent steps to analyze
      # @!attribute [r] similarity_threshold
      #   @return [Float] Minimum task-action similarity (0.0-1.0)
      # @!attribute [r] max_tangent_steps
      #   @return [Integer] Max consecutive off-topic steps before flagging
      DriftConfig = Data.define(:enabled, :window_size, :similarity_threshold, :max_tangent_steps) do
        def self.default
          new(
            enabled: true,
            window_size: 5,
            similarity_threshold: 0.3,
            max_tangent_steps: 3
          )
        end

        def self.disabled
          new(enabled: false, window_size: 0, similarity_threshold: 0.0, max_tangent_steps: 0)
        end

        def self.strict
          new(
            enabled: true,
            window_size: 3,
            similarity_threshold: 0.4,
            max_tangent_steps: 2
          )
        end
      end

      # Result of drift detection analysis.
      #
      # @!attribute [r] level
      #   @return [Symbol] Drift severity (:none, :mild, :moderate, :severe)
      # @!attribute [r] confidence
      #   @return [Float] Confidence in the assessment (0.0-1.0)
      # @!attribute [r] off_topic_count
      #   @return [Integer] Number of consecutive off-topic steps
      # @!attribute [r] task_relevance
      #   @return [Float] Overall relevance to original task (0.0-1.0)
      # @!attribute [r] guidance
      #   @return [String, nil] Suggested guidance if drifting
      DriftResult = Data.define(:level, :confidence, :off_topic_count, :task_relevance, :guidance) do
        # Whether any drift is detected.
        # @return [Boolean]
        def drifting? = level != :none

        # Whether drift is concerning (moderate or severe).
        # @return [Boolean]
        def concerning? = %i[moderate severe].include?(level)

        # Whether drift requires immediate intervention.
        # @return [Boolean]
        def critical? = level == :severe

        class << self
          # Create result indicating no drift.
          # @param task_relevance [Float] How relevant recent actions are
          # @return [DriftResult]
          def on_track(task_relevance: 1.0)
            new(
              level: :none,
              confidence: 0.9,
              off_topic_count: 0,
              task_relevance:,
              guidance: nil
            )
          end

          # Create result indicating drift detected.
          # @param level [Symbol] Drift severity
          # @param off_topic_count [Integer] Consecutive off-topic steps
          # @param task_relevance [Float] Overall task relevance
          # @param guidance [String] Suggested correction
          # @return [DriftResult]
          def drift_detected(level:, off_topic_count:, task_relevance:, guidance:)
            confidence = case level
                         when :mild then 0.6
                         when :moderate then 0.75
                         when :severe then 0.9
                         else 0.5
                         end
            new(level:, confidence:, off_topic_count:, task_relevance:, guidance:)
          end
        end
      end

      def self.included(base)
        base.attr_reader :drift_config
      end

      private

      def initialize_goal_drift(drift_config: nil)
        @drift_config = drift_config || DriftConfig.disabled
      end

      # Checks for goal drift in recent steps.
      #
      # Analyzes whether recent actions are relevant to the original task
      # and flags potential drift from the goal.
      #
      # @param task [String] The original task
      # @param recent_steps [Array<ActionStep>] Recent action steps
      # @return [DriftResult] Drift detection result
      def check_goal_drift(task, recent_steps)
        return DriftResult.on_track unless @drift_config&.enabled

        steps = Array(recent_steps).last(@drift_config.window_size)
        return DriftResult.on_track if steps.empty?

        # Calculate relevance for each step
        relevances = steps.map { |step| calculate_step_relevance(task, step) }
        avg_relevance = relevances.sum / relevances.size.to_f

        # Count consecutive off-topic steps (from most recent)
        off_topic_count = count_consecutive_off_topic(relevances)

        # Determine drift level
        level = determine_drift_level(avg_relevance, off_topic_count)
        guidance = generate_drift_guidance(task, level) if level != :none

        if level == :none
          DriftResult.on_track(task_relevance: avg_relevance)
        else
          DriftResult.drift_detected(
            level:,
            off_topic_count:,
            task_relevance: avg_relevance,
            guidance:
          )
        end
      end

      # Calculates how relevant a step is to the task.
      #
      # @param task [String] Original task
      # @param step [ActionStep] Step to evaluate
      # @return [Float] Relevance score (0.0-1.0)
      def calculate_step_relevance(task, step)
        task_terms = extract_key_terms(task)
        return 1.0 if task_terms.empty?

        step_text = build_step_text(step)
        step_terms = extract_key_terms(step_text)
        return 0.5 if step_terms.empty? # Neutral if no terms

        # Jaccard similarity of terms
        intersection = (task_terms & step_terms).size
        union = (task_terms | step_terms).size
        return 0.5 if union.zero?

        base_similarity = intersection.to_f / union

        # Boost for direct matches of important task words
        important_matches = count_important_matches(task, step_text)
        boost = [important_matches * 0.1, 0.3].min

        [base_similarity + boost, 1.0].min
      end

      # Extracts key terms from text for comparison.
      #
      # @param text [String] Text to extract from
      # @return [Set<String>] Set of key terms
      def extract_key_terms(text)
        return Set.new if text.nil? || text.empty?

        # Remove common stop words, keep meaningful terms
        stop_words = %w[the a an is are was were be been being have has had do does did
                        will would could should may might must shall can to of and in
                        for on with at by from or but not this that these those it its]

        text.to_s.downcase
            .gsub(/[^a-z0-9\s]/, " ")
            .split(/\s+/)
            .reject { |w| w.length < 3 || stop_words.include?(w) }
            .to_set
      end

      # Builds text representation of a step for analysis.
      #
      # @param step [ActionStep] Step to convert
      # @return [String] Text representation
      def build_step_text(step)
        parts = []

        if step.tool_calls&.any?
          step.tool_calls.each do |tc|
            parts << tc.name.to_s
            parts << tc.arguments.values.map(&:to_s).join(" ") if tc.arguments
          end
        end

        parts << step.code_action.to_s if step.code_action
        parts << step.observations.to_s if step.observations
        parts << step.action_output.to_s if step.action_output

        parts.join(" ")
      end

      # Counts important keyword matches between task and step.
      #
      # @param task [String] Original task
      # @param step_text [String] Step text
      # @return [Integer] Number of important matches
      def count_important_matches(task, step_text)
        # Extract potential entity/action words (capitalized or quoted)
        important = task.scan(/["']([^"']+)["']|\b([A-Z][a-z]+)\b/).flatten.compact
        return 0 if important.empty?

        step_lower = step_text.downcase
        important.count { |term| step_lower.include?(term.downcase) }
      end

      # Counts consecutive off-topic steps from the end.
      #
      # @param relevances [Array<Float>] Relevance scores (oldest to newest)
      # @return [Integer] Consecutive off-topic count
      def count_consecutive_off_topic(relevances)
        threshold = @drift_config.similarity_threshold
        count = 0

        relevances.reverse_each do |rel|
          break if rel >= threshold

          count += 1
        end

        count
      end

      # Determines drift level from metrics.
      #
      # @param avg_relevance [Float] Average task relevance
      # @param off_topic_count [Integer] Consecutive off-topic steps
      # @return [Symbol] Drift level
      def determine_drift_level(avg_relevance, off_topic_count)
        max_tangent = @drift_config.max_tangent_steps

        if off_topic_count >= max_tangent + 2 || avg_relevance < 0.15
          :severe
        elsif off_topic_count >= max_tangent || avg_relevance < 0.25
          :moderate
        elsif off_topic_count >= max_tangent - 1 || avg_relevance < 0.35
          :mild
        else
          :none
        end
      end

      # Generates guidance to correct drift.
      #
      # @param task [String] Original task
      # @param level [Symbol] Drift level
      # @return [String] Guidance message
      def generate_drift_guidance(task, level)
        task_summary = task.to_s.slice(0, 100)

        case level
        when :severe
          "CRITICAL: You have drifted far from the task. Stop and refocus.\n" \
            "Original task: #{task_summary}\n" \
            "Take a direct action toward completing this task or call final_answer."
        when :moderate
          "WARNING: Your recent actions seem unrelated to the task.\n" \
            "Refocus on: #{task_summary}\n" \
            "Consider what direct action will help complete the task."
        when :mild
          "Note: Recent actions may be tangential to the main task.\n" \
            "Remember the goal: #{task_summary}"
        end
      end

      # Executes drift check if configured and handles result.
      #
      # @param task [String] Original task
      # @param recent_steps [Array<ActionStep>] Recent steps
      # @yield [DriftResult] If block given and drifting, yields result
      # @return [DriftResult, nil] Result or nil if disabled
      def execute_drift_check_if_needed(task, recent_steps)
        return nil unless @drift_config&.enabled

        result = check_goal_drift(task, recent_steps)
        emit_drift_event(result) if result.drifting?
        log_drift_result(result)
        yield result if block_given? && result.drifting?
        result
      end

      def emit_drift_event(result)
        return unless respond_to?(:emit, true)

        emit(Events::GoalDriftDetected.create(
               level: result.level,
               task_relevance: result.task_relevance,
               off_topic_count: result.off_topic_count
             ))
      rescue NameError
        # Event not defined - skip
      end

      def log_drift_result(result)
        return unless @logger

        if result.critical?
          @logger.warn("Goal drift: severe", relevance: result.task_relevance.round(2))
        elsif result.concerning?
          @logger.info("Goal drift: moderate", relevance: result.task_relevance.round(2))
        elsif result.drifting?
          @logger.debug("Goal drift: mild", relevance: result.task_relevance.round(2))
        end
      end
    end
  end
end
