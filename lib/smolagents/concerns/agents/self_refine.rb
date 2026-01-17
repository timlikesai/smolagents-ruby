module Smolagents
  module Concerns
    # Self-Refine loop for iterative improvement.
    #
    # Research shows ~20% improvement with Generate → Feedback → Refine loops.
    # For small models, use external validation (ExecutionOracle) rather than
    # self-critique, as small models cannot reliably self-correct reasoning.
    #
    # @see https://arxiv.org/abs/2303.17651 Self-Refine paper
    # @see https://arxiv.org/abs/2310.01798 "LLMs Cannot Self-Correct" (ICLR 2024)
    #
    # @example Basic usage with execution feedback
    #   agent = Smolagents.agent
    #     .model { m }
    #     .refine(max_iterations: 3, feedback: :execution)
    #     .build
    #
    # @example Self-critique for capable models
    #   agent = Smolagents.agent
    #     .model { capable_model }
    #     .refine(max_iterations: 2, feedback: :self)
    #     .build
    module SelfRefine
      # Feedback sources for refinement.
      # - :execution - Use ExecutionOracle (recommended for small models)
      # - :self - Self-critique (only for capable models)
      # - :evaluation - Use evaluation phase results
      FEEDBACK_SOURCES = %i[execution self evaluation].freeze

      # Default refinement configuration.
      DEFAULT_MAX_ITERATIONS = 3
      DEFAULT_FEEDBACK_SOURCE = :execution

      # Configuration for self-refine behavior.
      #
      # @!attribute [r] max_iterations
      #   @return [Integer] Maximum refinement attempts (default: 3)
      # @!attribute [r] feedback_source
      #   @return [Symbol] Where to get feedback (:execution, :self, :evaluation)
      # @!attribute [r] min_confidence
      #   @return [Float] Minimum confidence to accept without refinement (0.0-1.0)
      # @!attribute [r] enabled
      #   @return [Boolean] Whether refinement is enabled
      RefineConfig = Data.define(:max_iterations, :feedback_source, :min_confidence, :enabled) do
        def self.default
          new(
            max_iterations: DEFAULT_MAX_ITERATIONS,
            feedback_source: DEFAULT_FEEDBACK_SOURCE,
            min_confidence: 0.8,
            enabled: true
          )
        end

        def self.disabled
          new(max_iterations: 0, feedback_source: :execution, min_confidence: 1.0, enabled: false)
        end
      end

      # Result of a refinement cycle.
      #
      # Tracks the refinement process including all iterations, feedback received,
      # and whether improvement was achieved.
      #
      # @!attribute [r] original
      #   @return [Object] Original response before refinement
      # @!attribute [r] refined
      #   @return [Object] Final refined response
      # @!attribute [r] iterations
      #   @return [Integer] Number of refinement iterations performed
      # @!attribute [r] feedback_history
      #   @return [Array<RefinementFeedback>] Feedback from each iteration
      # @!attribute [r] improved
      #   @return [Boolean] Whether refinement improved the result
      # @!attribute [r] confidence
      #   @return [Float] Final confidence score
      RefinementResult = Data.define(
        :original,
        :refined,
        :iterations,
        :feedback_history,
        :improved,
        :confidence
      ) do
        # Whether any refinement occurred.
        # @return [Boolean]
        def refined? = iterations.positive?

        # Whether max iterations were reached.
        # @param max [Integer] Maximum iterations
        # @return [Boolean]
        def maxed_out?(max) = iterations >= max

        # The final result (refined if improved, original otherwise).
        # @return [Object]
        def final = improved ? refined : original

        class << self
          # Create result when no refinement was needed.
          # @param response [Object] Original response
          # @param confidence [Float] Confidence level
          # @return [RefinementResult]
          def no_refinement_needed(response, confidence: 1.0)
            new(
              original: response,
              refined: response,
              iterations: 0,
              feedback_history: [],
              improved: false,
              confidence:
            )
          end

          # Create result after refinement attempts.
          # @param original [Object] Original response
          # @param refined [Object] Refined response
          # @param iterations [Integer] Number of iterations
          # @param feedback_history [Array] Feedback from iterations
          # @param improved [Boolean] Whether improvement occurred
          # @param confidence [Float] Final confidence
          # @return [RefinementResult]
          def after_refinement(original:, refined:, iterations:, feedback_history:, improved:, confidence:)
            new(original:, refined:, iterations:, feedback_history:, improved:, confidence:)
          end
        end
      end

      # Feedback from a single refinement iteration.
      #
      # @!attribute [r] iteration
      #   @return [Integer] Which iteration this feedback is from
      # @!attribute [r] source
      #   @return [Symbol] Feedback source (:execution, :self, :evaluation)
      # @!attribute [r] critique
      #   @return [String] The feedback/critique content
      # @!attribute [r] actionable
      #   @return [Boolean] Whether feedback is actionable
      # @!attribute [r] confidence
      #   @return [Float] Confidence in the feedback
      RefinementFeedback = Data.define(:iteration, :source, :critique, :actionable, :confidence) do
        # Whether this feedback suggests improvement is possible.
        # @return [Boolean]
        def suggests_improvement? = actionable && confidence > 0.5
      end

      # System prompt for self-critique.
      CRITIQUE_SYSTEM = <<~PROMPT.strip.freeze
        You are a code reviewer. Identify specific issues that can be fixed.
        Be concise. If the code is correct, say "LGTM".
      PROMPT

      def self.included(base)
        base.attr_reader :refine_config
      end

      private

      def initialize_self_refine(refine_config: nil)
        @refine_config = refine_config || RefineConfig.disabled
      end

      # Attempts to refine a step's output through iterative feedback.
      #
      # This is the main entry point for refinement. It:
      # 1. Gets feedback on the current output
      # 2. If actionable, asks the model to refine
      # 3. Repeats until confident or max iterations reached
      #
      # @param step [ActionStep] The step to potentially refine
      # @param task [String] The original task for context
      # @return [RefinementResult] The refinement outcome
      def attempt_refinement(step, task)
        return RefinementResult.no_refinement_needed(step) unless @refine_config&.enabled

        original_output = step.action_output
        current_output = original_output
        feedback_history = []
        iterations = 0

        while iterations < @refine_config.max_iterations
          feedback = get_refinement_feedback(current_output, step, task, iterations)
          feedback_history << feedback

          break unless feedback.suggests_improvement?

          iterations += 1
          refined_output = apply_refinement(current_output, feedback, task)

          # Check if refinement actually changed anything
          break if refined_output == current_output

          current_output = refined_output
        end

        improved = current_output != original_output
        confidence = feedback_history.last&.confidence || 1.0

        RefinementResult.after_refinement(
          original: original_output,
          refined: current_output,
          iterations:,
          feedback_history:,
          improved:,
          confidence:
        )
      end

      # Gets feedback based on configured source.
      #
      # @param output [Object] Current output to evaluate
      # @param step [ActionStep] The step context
      # @param task [String] Original task
      # @param iteration [Integer] Current iteration number
      # @return [RefinementFeedback] Feedback for this iteration
      def get_refinement_feedback(output, step, task, iteration)
        case @refine_config.feedback_source
        when :execution
          execution_feedback(output, step, iteration)
        when :self
          self_critique_feedback(output, task, iteration)
        when :evaluation
          evaluation_feedback(output, step, task, iteration)
        else
          RefinementFeedback.new(
            iteration:,
            source: :none,
            critique: "Unknown feedback source",
            actionable: false,
            confidence: 0.0
          )
        end
      end

      # Gets feedback from ExecutionOracle.
      #
      # Uses execution results as ground truth - the most reliable
      # feedback source for small models.
      #
      # @param output [Object] Current output
      # @param step [ActionStep] Step with execution result
      # @param iteration [Integer] Current iteration
      # @return [RefinementFeedback]
      def execution_feedback(_output, step, iteration)
        # Check if step has an execution error
        if step.error
          # Use ExecutionOracle if available
          if respond_to?(:analyze_execution, true)
            result = step.respond_to?(:execution_result) ? step.execution_result : nil
            if result
              oracle_feedback = analyze_execution(result, step.code_action)
              return RefinementFeedback.new(
                iteration:,
                source: :execution,
                critique: oracle_feedback.to_observation,
                actionable: oracle_feedback.actionable?,
                confidence: oracle_feedback.confidence
              )
            end
          end

          # Fallback: use error message directly
          RefinementFeedback.new(
            iteration:,
            source: :execution,
            critique: "Execution error: #{step.error}",
            actionable: true,
            confidence: 0.7
          )
        else
          # No error - output looks good
          RefinementFeedback.new(
            iteration:,
            source: :execution,
            critique: "Execution succeeded",
            actionable: false,
            confidence: 0.9
          )
        end
      end

      # Gets feedback through self-critique.
      #
      # Only recommended for capable models. Small models cannot
      # reliably self-correct reasoning errors.
      #
      # @param output [Object] Current output
      # @param task [String] Original task
      # @param iteration [Integer] Current iteration
      # @return [RefinementFeedback]
      def self_critique_feedback(output, task, iteration)
        prompt = build_critique_prompt(output, task)
        messages = [
          ChatMessage.system(CRITIQUE_SYSTEM),
          ChatMessage.user(prompt)
        ]

        response = @model.generate(messages, max_tokens: 150)
        parse_critique_response(response.content, iteration)
      end

      # Gets feedback from evaluation phase.
      #
      # Uses the evaluation concern's results if available.
      #
      # @param output [Object] Current output
      # @param step [ActionStep] Step context
      # @param task [String] Original task
      # @param iteration [Integer] Current iteration
      # @return [RefinementFeedback]
      def evaluation_feedback(_output, step, task, iteration)
        # Use evaluation if available
        if respond_to?(:evaluate_progress, true)
          result = evaluate_progress(task, step, iteration + 1)
          RefinementFeedback.new(
            iteration:,
            source: :evaluation,
            critique: result.reasoning || result.answer || "Evaluation complete",
            actionable: result.continue? || result.stuck?,
            confidence: result.confidence || 0.5
          )
        else
          RefinementFeedback.new(
            iteration:,
            source: :evaluation,
            critique: "Evaluation not available",
            actionable: false,
            confidence: 0.5
          )
        end
      end

      # Builds the critique prompt.
      def build_critique_prompt(output, task)
        <<~PROMPT
          Task: #{task}
          Output: #{output.to_s.slice(0, 500)}

          Review this output. Is it correct and complete?
          If issues exist, describe ONE specific fix.
          Format: ISSUE: <problem> | FIX: <solution>
          Or if correct: LGTM
        PROMPT
      end

      # Parses self-critique response.
      def parse_critique_response(content, iteration)
        text = content.strip

        if text.upcase.include?("LGTM") || text.upcase.include?("LOOKS GOOD")
          RefinementFeedback.new(
            iteration:,
            source: :self,
            critique: "Code looks good",
            actionable: false,
            confidence: 0.8
          )
        elsif text =~ /ISSUE:\s*(.+?)\s*\|\s*FIX:\s*(.+)/mi
          issue = ::Regexp.last_match(1).strip
          fix = ::Regexp.last_match(2).strip
          RefinementFeedback.new(
            iteration:,
            source: :self,
            critique: "#{issue}. Fix: #{fix}",
            actionable: true,
            confidence: 0.7
          )
        else
          # Unclear format - assume there's feedback
          RefinementFeedback.new(
            iteration:,
            source: :self,
            critique: text,
            actionable: text.length > 20,
            confidence: 0.5
          )
        end
      end

      # Applies refinement by asking model to fix based on feedback.
      #
      # @param current_output [Object] Current output to refine
      # @param feedback [RefinementFeedback] Feedback to apply
      # @param task [String] Original task
      # @return [Object] Refined output
      def apply_refinement(current_output, feedback, task)
        prompt = <<~PROMPT
          Task: #{task}
          Current code/output: #{current_output.to_s.slice(0, 500)}
          Feedback: #{feedback.critique}

          Fix the issue and provide the corrected code only.
        PROMPT

        messages = [
          ChatMessage.system("You fix code based on feedback. Output only the corrected code."),
          ChatMessage.user(prompt)
        ]

        response = @model.generate(messages, max_tokens: 500)
        response.content.strip
      end

      # Executes refinement if configured, wrapping step execution.
      #
      # @param step [ActionStep] Step to potentially refine
      # @param task [String] Original task
      # @yield [RefinementResult] If block given, yields result
      # @return [RefinementResult, nil] Result or nil if disabled
      def execute_refinement_if_needed(step, task)
        return nil unless @refine_config&.enabled
        return nil if step.is_final_answer

        result = attempt_refinement(step, task)
        emit_refinement_event(result) if result.refined?
        log_refinement_result(result)
        yield result if block_given?
        result
      end

      def emit_refinement_event(result)
        return unless respond_to?(:emit, true)

        emit(Events::RefinementCompleted.create(
               iterations: result.iterations,
               improved: result.improved,
               confidence: result.confidence
             ))
      rescue NameError
        # Event not defined - skip
      end

      def log_refinement_result(result)
        return unless @logger

        if result.improved
          @logger.info("Refinement improved output", iterations: result.iterations)
        elsif result.refined?
          @logger.debug("Refinement attempted but no improvement", iterations: result.iterations)
        end
      end
    end
  end
end
