module Smolagents
  module Concerns
    # Reflection Memory for learning from failures across attempts.
    #
    # Research shows 91% pass@1 on HumanEval with reflection memory.
    # The key insight: store reflections like "Last time I tried X, it failed because Y"
    # and inject them into future attempts.
    #
    # @see https://arxiv.org/abs/2303.11366 Reflexion paper
    #
    # @example Basic usage
    #   agent = Smolagents.agent
    #     .model { m }
    #     .reflect(max_reflections: 5)
    #     .build
    #
    #   # After a failure, reflection is stored
    #   # On retry, past reflections are injected
    module ReflectionMemory
      # Maximum reflections to store (prevents unbounded growth).
      DEFAULT_MAX_REFLECTIONS = 10

      # Configuration for reflection memory.
      #
      # @!attribute [r] max_reflections
      #   @return [Integer] Maximum reflections to store (default: 10)
      # @!attribute [r] enabled
      #   @return [Boolean] Whether reflection is enabled
      # @!attribute [r] include_successful
      #   @return [Boolean] Whether to store reflections on success too
      ReflectionConfig = Data.define(:max_reflections, :enabled, :include_successful) do
        def self.default
          new(max_reflections: DEFAULT_MAX_REFLECTIONS, enabled: true, include_successful: false)
        end

        def self.disabled
          new(max_reflections: 0, enabled: false, include_successful: false)
        end
      end

      # A single reflection entry.
      #
      # Captures what was tried, what happened, and what to do differently.
      #
      # @!attribute [r] task
      #   @return [String] The task being attempted
      # @!attribute [r] action
      #   @return [String] What action was taken
      # @!attribute [r] outcome
      #   @return [Symbol] :success, :failure, :partial
      # @!attribute [r] observation
      #   @return [String] What was observed (error message, result)
      # @!attribute [r] reflection
      #   @return [String] What to do differently next time
      # @!attribute [r] timestamp
      #   @return [Time] When this reflection was created
      Reflection = Data.define(:task, :action, :outcome, :observation, :reflection, :timestamp) do
        # Whether this was a failure.
        # @return [Boolean]
        def failure? = outcome == :failure

        # Whether this was successful.
        # @return [Boolean]
        def success? = outcome == :success

        # Format for injection into agent context.
        # @return [String]
        def to_context
          "Previous attempt: #{action}\nResult: #{outcome} - #{observation}\nLesson: #{reflection}"
        end

        class << self
          # Create reflection from a failed step.
          # @param task [String] The task
          # @param step [ActionStep] The failed step
          # @param reflection_text [String] What to do differently
          # @return [Reflection]
          def from_failure(task:, step:, reflection_text:)
            new(
              task: task.to_s.slice(0, 200),
              action: extract_action(step),
              outcome: :failure,
              observation: step.error || step.observations.to_s.slice(0, 200),
              reflection: reflection_text,
              timestamp: Time.now
            )
          end

          # Create reflection from a successful step.
          # @param task [String] The task
          # @param step [ActionStep] The successful step
          # @param reflection_text [String] What worked well
          # @return [Reflection]
          def from_success(task:, step:, reflection_text:)
            new(
              task: task.to_s.slice(0, 200),
              action: extract_action(step),
              outcome: :success,
              observation: step.action_output.to_s.slice(0, 200),
              reflection: reflection_text,
              timestamp: Time.now
            )
          end

          private

          def extract_action(step)
            if step.tool_calls&.any?
              step.tool_calls.map { |tc| "#{tc.name}(#{tc.arguments.keys.join(", ")})" }.join(", ")
            elsif step.code_action
              step.code_action.to_s.slice(0, 100)
            else
              "unknown action"
            end
          end
        end
      end

      # In-memory reflection store with LRU eviction.
      #
      # Thread-safe storage for reflections with automatic eviction
      # when max capacity is reached.
      class ReflectionStore
        def initialize(max_size: DEFAULT_MAX_REFLECTIONS)
          @max_size = max_size
          @reflections = []
          @mutex = Mutex.new
        end

        # Add a reflection, evicting oldest if at capacity.
        # @param reflection [Reflection] The reflection to store
        # @return [Reflection] The stored reflection
        def add(reflection)
          @mutex.synchronize do
            @reflections.shift while @reflections.size >= @max_size
            @reflections << reflection
          end
          reflection
        end

        # Get all reflections.
        # @return [Array<Reflection>]
        def all
          @mutex.synchronize { @reflections.dup }
        end

        # Get reflections relevant to a task.
        # @param task [String] The current task
        # @param limit [Integer] Maximum reflections to return
        # @return [Array<Reflection>]
        def relevant_to(task, limit: 3)
          @mutex.synchronize do
            # Simple relevance: most recent failures first, then by task similarity
            @reflections
              .select(&:failure?)
              .sort_by { |r| [-task_similarity(task, r.task), -r.timestamp.to_i] }
              .first(limit)
          end
        end

        # Get only failure reflections.
        # @return [Array<Reflection>]
        def failures
          @mutex.synchronize { @reflections.select(&:failure?) }
        end

        # Clear all reflections.
        # @return [void]
        def clear
          @mutex.synchronize { @reflections.clear }
        end

        # Number of stored reflections.
        # @return [Integer]
        def size
          @mutex.synchronize { @reflections.size }
        end

        private

        # Simple task similarity based on word overlap.
        def task_similarity(task1, task2)
          words1 = task1.to_s.downcase.split(/\W+/).to_set
          words2 = task2.to_s.downcase.split(/\W+/).to_set
          return 0.0 if words1.empty? || words2.empty?

          (words1 & words2).size.to_f / (words1 | words2).size
        end
      end

      def self.included(base)
        base.attr_reader :reflection_config, :reflection_store
      end

      private

      def initialize_reflection_memory(reflection_config: nil)
        @reflection_config = reflection_config || ReflectionConfig.disabled
        @reflection_store = ReflectionStore.new(max_size: @reflection_config.max_reflections)
      end

      # Records a reflection from a step outcome.
      #
      # For failures, generates a reflection about what went wrong.
      # For successes (if configured), records what worked.
      #
      # @param step [ActionStep] The step to reflect on
      # @param task [String] The current task
      # @return [Reflection, nil] The recorded reflection or nil
      def record_reflection(step, task)
        return nil unless @reflection_config&.enabled
        return nil if step.is_final_answer

        if step.error
          reflection = generate_failure_reflection(step, task)
          @reflection_store.add(reflection)
          emit_reflection_event(reflection)
          log_reflection(reflection)
          reflection
        elsif @reflection_config.include_successful && step.action_output
          reflection = generate_success_reflection(step, task)
          @reflection_store.add(reflection)
          reflection
        end
      end

      # Gets relevant past reflections for the current task.
      #
      # @param task [String] The current task
      # @param limit [Integer] Maximum reflections to return
      # @return [Array<Reflection>] Relevant reflections
      def get_relevant_reflections(task, limit: 3)
        return [] unless @reflection_config&.enabled

        @reflection_store.relevant_to(task, limit:)
      end

      # Formats reflections for injection into agent context.
      #
      # @param reflections [Array<Reflection>] Reflections to format
      # @return [String] Formatted reflection context
      def format_reflections_for_context(reflections)
        return "" if reflections.empty?

        header = "## Lessons from Previous Attempts\n\n"
        body = reflections.map.with_index(1) do |r, i|
          "#{i}. #{r.to_context}"
        end.join("\n\n")

        "#{header}#{body}\n"
      end

      # Injects reflections into task prompt if available.
      #
      # @param task [String] The original task
      # @return [String] Task with reflections prepended
      def inject_reflections(task)
        reflections = get_relevant_reflections(task)
        return task if reflections.empty?

        context = format_reflections_for_context(reflections)
        "#{context}\n## Current Task\n\n#{task}"
      end

      # Generates a reflection from a failed step.
      #
      # Uses the error message and context to create actionable guidance.
      #
      # @param step [ActionStep] The failed step
      # @param task [String] The current task
      # @return [Reflection]
      def generate_failure_reflection(step, task)
        error = step.error.to_s
        reflection_text = infer_reflection_from_error(error, step)

        Reflection.from_failure(
          task:,
          step:,
          reflection_text:
        )
      end

      # Generates a reflection from a successful step.
      #
      # @param step [ActionStep] The successful step
      # @param task [String] The current task
      # @return [Reflection]
      def generate_success_reflection(step, task)
        Reflection.from_success(
          task:,
          step:,
          reflection_text: "This approach worked - consider reusing"
        )
      end

      # Infers actionable reflection from error message.
      #
      # Uses error patterns to generate specific guidance.
      #
      # @param error [String] The error message
      # @param step [ActionStep] The step context
      # @return [String] Actionable reflection
      def infer_reflection_from_error(error, _step)
        case error
        when /undefined local variable or method [`'](\w+)'/
          "Define #{::Regexp.last_match(1)} before using it, or check spelling"
        when /undefined method [`'](\w+)'/
          "Method #{::Regexp.last_match(1)} doesn't exist - use a different approach"
        when /wrong number of arguments/
          "Check the method signature and pass correct number of arguments"
        when /no implicit conversion/
          "Add explicit type conversion (.to_s, .to_i, etc.)"
        when /syntax error/
          "Check brackets, quotes, and keyword pairs (do/end, if/end)"
        when /Tool.*not found/i
          "Use only available tools - list them first if unsure"
        when /timeout|timed out/i
          "Simplify the approach or break into smaller steps"
        else
          "Avoid this approach - try something different"
        end
      end

      def emit_reflection_event(reflection)
        return unless respond_to?(:emit, true)

        emit(Events::ReflectionRecorded.create(
               outcome: reflection.outcome,
               reflection: reflection.reflection
             ))
      rescue NameError
        # Event not defined - skip
      end

      def log_reflection(reflection)
        return unless @logger

        @logger.debug("Reflection recorded", outcome: reflection.outcome, lesson: reflection.reflection.slice(0, 50))
      end
    end
  end
end
