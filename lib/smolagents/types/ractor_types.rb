module Smolagents
  module Types
    # Ractor Shareability Rules for Data.define Types
    #
    # Data.define objects ARE Ractor-shareable when ALL their values are shareable.
    # This is a critical architectural constraint for any code using Ractors.
    #
    # == Shareable Values
    #
    # * Primitives: Integer, Float, Symbol, nil, true, false
    # * Frozen strings: "hello".freeze or frozen string literals
    # * Frozen arrays/hashes with shareable contents
    # * Nested Data.define objects (if their values are shareable)
    # * Class/Module references
    #
    # == NOT Shareable
    #
    # * Unfrozen strings (use .freeze or Ractor.make_shareable)
    # * Procs/Lambdas (NEVER shareable as values)
    # * Arbitrary object instances (unless explicitly made shareable)
    #
    # == Key Insight
    #
    # Custom methods defined in a Data.define block do NOT affect shareability.
    # Methods are stored on the class, not as Procs in the instance.
    #
    # == Example
    #
    #   # This IS shareable - primitives and frozen strings
    #   task = RactorTask.create(agent_name: "test", prompt: "hello")
    #   Ractor.shareable?(task)  # => true
    #
    #   # This is NOT shareable - config contains complex objects
    #   task = RactorTask.new(..., config: { model: OpenAIModel.new(...) })
    #   Ractor.shareable?(task)  # => false
    #
    # See PLAN.md "Data.define Ractor Shareability" for comprehensive documentation.

    # Task submitted to a child Ractor for agent execution.
    #
    # RactorTask encapsulates all information needed to run an agent task
    # in an isolated Ractor, including configuration and tracing.
    #
    # @example Creating a task
    #   task = Types::RactorTask.create(
    #     agent_name: "researcher",
    #     prompt: "Find latest news on Ruby 4.0",
    #     timeout: 60
    #   )
    RactorTask = Data.define(:task_id, :agent_name, :prompt, :config, :timeout, :trace_id) do
      def self.create(agent_name:, prompt:, config: {}, timeout: 30, trace_id: nil)
        new(
          task_id: SecureRandom.uuid,
          agent_name:,
          prompt:,
          config: deep_freeze(config),
          timeout:,
          trace_id: trace_id || SecureRandom.uuid
        )
      end

      def self.deep_freeze(obj)
        case obj
        when Hash then obj.transform_keys { |k| deep_freeze(k) }.transform_values { |v| deep_freeze(v) }.freeze
        when Array then obj.map { |v| deep_freeze(v) }.freeze
        when String then obj.frozen? ? obj : obj.dup.freeze
        else obj
        end
      end

      def deconstruct_keys(_) = { task_id:, agent_name:, prompt:, config:, timeout:, trace_id: }
    end

    # Successful result from a sub-agent Ractor.
    #
    # @example Creating from run result
    #   success = Types::RactorSuccess.from_result(
    #     task_id: task.task_id,
    #     run_result: result,
    #     duration: 2.5,
    #     trace_id: task.trace_id
    #   )
    RactorSuccess = Data.define(:task_id, :output, :steps_taken, :token_usage, :duration, :trace_id) do
      def self.from_result(task_id:, run_result:, duration:, trace_id:)
        new(
          task_id:,
          output: run_result.output,
          steps_taken: run_result.steps&.size || 0,
          token_usage: run_result.token_usage,
          duration:,
          trace_id:
        )
      end

      def success? = true
      def failure? = false

      def deconstruct_keys(_) = { task_id:, output:, steps_taken:, token_usage:, duration:, trace_id:, success: true }
    end

    # Failed result from a sub-agent Ractor.
    #
    # @example Creating from exception
    #   failure = Types::RactorFailure.from_exception(
    #     task_id: task.task_id,
    #     error: exception,
    #     trace_id: task.trace_id
    #   )
    RactorFailure = Data.define(:task_id, :error_class, :error_message, :steps_taken, :duration, :trace_id) do
      def self.from_exception(task_id:, error:, trace_id:, steps_taken: 0, duration: 0)
        new(
          task_id:,
          error_class: error.class.name,
          error_message: error.message,
          steps_taken:,
          duration:,
          trace_id:
        )
      end

      def success? = false
      def failure? = true

      def deconstruct_keys(_) = { task_id:, error_class:, error_message:, steps_taken:, duration:, trace_id:, success: false }
    end

    # Valid message types for Ractor communication
    RACTOR_MESSAGE_TYPES = %i[task result].freeze

    # Message envelope for type-safe Ractor communication.
    #
    # @example Sending a task
    #   message = Types::RactorMessage.task(task)
    #   ractor.send(message)
    RactorMessage = Data.define(:type, :payload) do
      def self.task(task) = new(type: :task, payload: task)
      def self.result(result) = new(type: :result, payload: result)

      def task? = type == :task
      def result? = type == :result

      def deconstruct_keys(_) = { type:, payload: }
    end

    # Aggregated result from orchestrated parallel execution.
    #
    # @example Checking orchestrator results
    #   result = orchestrator.run_parallel(tasks)
    #   if result.all_success?
    #     puts "All #{result.success_count} tasks succeeded"
    #   else
    #     puts "#{result.failure_count} tasks failed"
    #   end
    OrchestratorResult = Data.define(:succeeded, :failed, :duration) do
      def self.create(succeeded:, failed:, duration:)
        new(
          succeeded: succeeded.freeze,
          failed: failed.freeze,
          duration:
        )
      end

      def all_success? = failed.empty?
      def any_success? = succeeded.any?
      def all_failed? = succeeded.empty? && failed.any?

      def success_count = succeeded.size
      def failure_count = failed.size
      def total_count = succeeded.size + failed.size

      def total_tokens
        succeeded.sum { |r| r.token_usage&.total_tokens || 0 }
      end

      def total_steps
        succeeded.sum(&:steps_taken) + failed.sum(&:steps_taken)
      end

      def outputs = succeeded.map(&:output)
      def errors = failed.map(&:error_message)

      def deconstruct_keys(_)
        { succeeded:, failed:, duration:, all_success: all_success?, success_count:, failure_count: }
      end
    end
  end
end
