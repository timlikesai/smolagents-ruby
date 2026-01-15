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
    #   task = RactorTask.new(..., config: { model: OpenAIModel.lm_studio("gemma-3n-e4b") })
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
      # Creates a new RactorTask with auto-generated IDs and deep-frozen config.
      #
      # Generates unique task_id and trace_id if not provided. All configuration
      # is deep frozen to ensure Ractor shareability.
      #
      # @param agent_name [String] the name of the agent to execute
      # @param prompt [String] the task prompt/instructions
      # @param config [Hash] agent configuration (default: {})
      # @param timeout [Integer] execution timeout in seconds (default: 30)
      # @param trace_id [String, nil] optional trace ID for request tracking
      #
      # @return [RactorTask] a new task instance
      #
      # @example With defaults
      #   task = Types::RactorTask.create(
      #     agent_name: "researcher",
      #     prompt: "Find Ruby news"
      #   )
      #
      # @example With custom timeout and trace ID
      #   task = Types::RactorTask.create(
      #     agent_name: "analyzer",
      #     prompt: "Analyze data",
      #     timeout: 120,
      #     trace_id: "trace-001"
      #   )
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

      # Deep freezes objects to ensure Ractor shareability.
      #
      # Recursively freezes hashes, arrays, and strings. Other objects
      # are returned as-is. Essential for ensuring task data is shareable
      # across Ractor boundaries.
      #
      # @param obj [Object] the object to freeze
      #
      # @return [Object] the frozen object (or original if already frozen/non-freezable)
      #
      # @example Freezing a config hash
      #   frozen = Types::RactorTask.deep_freeze({ model: "gpt-4", timeout: 30 })
      #   frozen.frozen?  # => true
      #
      # @example Nested structures
      #   frozen = Types::RactorTask.deep_freeze({
      #     tags: ["urgent", "review"],
      #     settings: { max_steps: 10 }
      #   })
      #   frozen[:tags].frozen?  # => true
      def self.deep_freeze(obj)
        case obj
        when Hash then deep_freeze_hash(obj)
        when Array then obj.map { |v| deep_freeze(v) }.freeze
        when String then freeze_string(obj)
        else obj
        end
      end

      def self.deep_freeze_hash(hash)
        hash.transform_keys { |k| deep_freeze(k) }.transform_values { |v| deep_freeze(v) }.freeze
      end

      def self.freeze_string(str) = str.frozen? ? str : str.dup.freeze

      # Deconstructs the task for pattern matching and keyword argument forwarding.
      #
      # @param _ [Object] ignored (required by pattern matching protocol)
      #
      # @return [Hash{Symbol => Object}] hash of all task attributes
      #
      # @example Pattern matching
      #   case task
      #   in { task_id:, agent_name:, prompt: }
      #     puts "Task #{task_id} for #{agent_name}"
      #   end
      #
      # @example Keyword argument forwarding
      #   def process(**attrs)
      #     attrs.fetch(:agent_name)
      #   end
      #   result = process(**task.deconstruct_keys(nil))
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
      # Creates a RactorSuccess from a RunResult.
      #
      # Extracts relevant information from a RunResult: the output, number of
      # steps taken, and token usage. Preserves task_id and trace_id for
      # request tracing.
      #
      # @param task_id [String] the original task ID
      # @param run_result [Types::RunResult] the agent's run result
      # @param duration [Numeric] execution duration in seconds
      # @param trace_id [String] trace ID for request tracking
      #
      # @return [RactorSuccess] a new success result instance
      #
      # @example Converting a successful run
      #   result = Types::RactorSuccess.from_result(
      #     task_id: "task-123",
      #     run_result: agent_run_result,
      #     duration: 5.2,
      #     trace_id: "trace-456"
      #   )
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

      # Deconstructs the result for pattern matching and keyword argument forwarding.
      #
      # Includes a calculated :success field set to true.
      #
      # @param _ [Object] ignored (required by pattern matching protocol)
      #
      # @return [Hash{Symbol => Object}] hash with success: true and all attributes
      #
      # @example Pattern matching
      #   case result
      #   in RactorSuccess[output:, steps_taken:]
      #     puts "Success after #{steps_taken} steps: #{output}"
      #   end
      #
      # @example Checking success status
      #   hash = result.deconstruct_keys(nil)
      #   hash[:success]  # => true
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
      # Creates a RactorFailure from an exception.
      #
      # Extracts error class name and message from an exception, preserving
      # task_id and trace_id for request tracing. Allows optional step and
      # duration information to be recorded.
      #
      # @param task_id [String] the original task ID
      # @param error [StandardError] the exception that was raised
      # @param trace_id [String] trace ID for request tracking
      # @param steps_taken [Integer] number of steps taken before failure (default: 0)
      # @param duration [Numeric] execution duration in seconds (default: 0)
      #
      # @return [RactorFailure] a new failure result instance
      #
      # @example Converting an exception
      #   failure = Types::RactorFailure.from_exception(
      #     task_id: "task-789",
      #     error: TimeoutError.new("Execution timeout"),
      #     trace_id: "trace-123",
      #     steps_taken: 3,
      #     duration: 30.5
      #   )
      #
      # @example With minimal info
      #   failure = Types::RactorFailure.from_exception(
      #     task_id: task.task_id,
      #     error: ex,
      #     trace_id: task.trace_id
      #   )
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

      # Deconstructs the result for pattern matching and keyword argument forwarding.
      #
      # Includes a calculated :success field set to false.
      #
      # @param _ [Object] ignored (required by pattern matching protocol)
      #
      # @return [Hash{Symbol => Object}] hash with success: false and all attributes
      #
      # @example Pattern matching
      #   case result
      #   in RactorFailure[error_class:, error_message:]
      #     puts "Failed with #{error_class}: #{error_message}"
      #   end
      #
      # @example Checking failure status
      #   hash = result.deconstruct_keys(nil)
      #   hash[:success]  # => false
      def deconstruct_keys(_)
        { task_id:, error_class:, error_message:, steps_taken:, duration:, trace_id:,
          success: false }
      end
    end

    # Valid message types for Ractor communication
    RACTOR_MESSAGE_TYPES = %i[task result].freeze

    # Message envelope for type-safe Ractor communication.
    #
    # @example Sending a task
    #   message = Types::RactorMessage.task(task)
    #   ractor.send(message)
    RactorMessage = Data.define(:type, :payload) do
      # Creates a RactorMessage containing a task.
      #
      # @param task [RactorTask] the task to wrap
      #
      # @return [RactorMessage] a message with type: :task
      #
      # @example Creating a task message
      #   message = Types::RactorMessage.task(task)
      #   message.task?  # => true
      #   message.payload == task  # => true
      def self.task(task) = new(type: :task, payload: task)

      # Creates a RactorMessage containing a result.
      #
      # @param result [RactorSuccess, RactorFailure] the result to wrap
      #
      # @return [RactorMessage] a message with type: :result
      #
      # @example Creating a result message
      #   message = Types::RactorMessage.result(success)
      #   message.result?  # => true
      #   message.payload == success  # => true
      def self.result(result) = new(type: :result, payload: result)

      def task? = type == :task
      def result? = type == :result

      # Deconstructs the message for pattern matching and keyword argument forwarding.
      #
      # @param _ [Object] ignored (required by pattern matching protocol)
      #
      # @return [Hash{Symbol => Object}] hash with message type and payload
      #
      # @example Pattern matching on message type
      #   case message
      #   in RactorMessage[type: :task, payload:]
      #     process_task(payload)
      #   in RactorMessage[type: :result, payload:]
      #     handle_result(payload)
      #   end
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
      # Creates an OrchestratorResult with frozen result collections.
      #
      # Freezes the succeeded and failed arrays to ensure immutability and
      # Ractor shareability.
      #
      # @param succeeded [Array<RactorSuccess>] successfully completed tasks
      # @param failed [Array<RactorFailure>] failed tasks
      # @param duration [Numeric] total execution duration in seconds
      #
      # @return [OrchestratorResult] a new aggregated result instance
      #
      # @example Creating orchestrator result
      #   result = Types::OrchestratorResult.create(
      #     succeeded: [success1, success2],
      #     failed: [failure1],
      #     duration: 15.3
      #   )
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

      # Returns the number of successful task results.
      #
      # @return [Integer] count of succeeded tasks
      #
      # @example
      #   result.success_count  # => 8
      def success_count = succeeded.size

      # Returns the number of failed task results.
      #
      # @return [Integer] count of failed tasks
      #
      # @example
      #   result.failure_count  # => 2
      def failure_count = failed.size

      # Returns the total number of tasks (succeeded + failed).
      #
      # @return [Integer] total task count
      #
      # @example
      #   result.total_count  # => 10
      def total_count = succeeded.size + failed.size

      # Returns the total tokens used across all succeeded tasks.
      #
      # Sums token_usage.total_tokens from all successful results, handling
      # nil values gracefully.
      #
      # @return [Integer] total tokens used
      #
      # @example
      #   result.total_tokens  # => 12500
      def total_tokens
        succeeded.sum { |r| r.token_usage&.total_tokens || 0 }
      end

      # Returns the total steps taken across all tasks.
      #
      # Sums steps_taken from both succeeded and failed results.
      #
      # @return [Integer] total steps across all tasks
      #
      # @example
      #   result.total_steps  # => 47
      def total_steps
        succeeded.sum(&:steps_taken) + failed.sum(&:steps_taken)
      end

      # Returns the output from each successful task.
      #
      # @return [Array<Object>] list of outputs from succeeded tasks
      #
      # @example
      #   result.outputs  # => ["Result 1", "Result 2", ...]
      def outputs = succeeded.map(&:output)

      # Returns the error message from each failed task.
      #
      # @return [Array<String>] list of error messages from failed tasks
      #
      # @example
      #   result.errors  # => ["Timeout after 30s", "Invalid input", ...]
      def errors = failed.map(&:error_message)

      # Deconstructs the result for pattern matching and keyword argument forwarding.
      #
      # Includes calculated fields: all_success, success_count, and failure_count.
      #
      # @param _ [Object] ignored (required by pattern matching protocol)
      #
      # @return [Hash{Symbol => Object}] hash with aggregated statistics
      #
      # @example Pattern matching on success
      #   case result
      #   in OrchestratorResult[all_success: true, success_count:]
      #     puts "All #{success_count} tasks succeeded"
      #   in OrchestratorResult[all_success: false, failure_count:, errors:]
      #     puts "#{failure_count} failed: #{errors.inspect}"
      #   end
      #
      # @example Accessing computed fields
      #   hash = result.deconstruct_keys(nil)
      #   hash[:all_success]  # => true
      #   hash[:success_count]  # => 8
      def deconstruct_keys(_)
        { succeeded:, failed:, duration:, all_success: all_success?, success_count:, failure_count: }
      end
    end
  end
end
