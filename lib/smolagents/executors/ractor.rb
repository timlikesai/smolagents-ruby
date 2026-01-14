require "stringio"

module Smolagents
  module Executors
    # Ractor-based code executor for thread-safe isolation.
    #
    # Ractor executes code in isolated Ractor instances for true parallelism
    # with memory isolation. Each execution runs in its own Ractor, completely
    # separate from the caller. No shared mutable state exists between executions.
    #
    # == Execution Modes
    #
    # The executor automatically selects the optimal strategy:
    #
    # 1. **Isolated execution** (no tools) - Simplest path
    #    - Code runs in its own Ractor
    #    - Variables are copied in, frozen for shareability
    #    - No tool support needed
    #
    # 2. **Tool-supporting execution** (has tools) - Message-based
    #    - Code runs in its own Ractor
    #    - Tool calls trigger messages back to main Ractor
    #    - Main Ractor executes tools, sends results back
    #    - Roundtrip for each tool call
    #
    # == Shareability Rules
    #
    # Data crossing Ractor boundaries must be shareable:
    # - Primitives (Integer, Float, Symbol, true, false, nil) - always shareable
    # - Frozen strings - shareable by reference
    # - Frozen arrays/hashes - shareable if contents are shareable
    # - Data.define instances - shareable if all fields are shareable
    # - Procs/Lambdas - NEVER shareable
    #
    # The executor automatically prepares objects for Ractor boundaries using
    # prepare_for_ractor, which freezes or converts to safe representations.
    #
    # == Features
    #
    # - True parallelism (not limited by Global VM Lock)
    # - Complete memory isolation between executions
    # - Tool calls routed through safe message passing
    # - Operation limits via TracePoint (line-based, :call unsupported)
    # - Automatic object serialization for boundary crossing
    #
    # @note Requires Ruby 3.0+ with Ractor support enabled
    # @note Objects passed to Ractors must be shareable or JSON-serializable
    # @note Ractors have ~20ms overhead compared to LocalRuby
    #
    # @example Basic isolated execution
    #   executor = Executors::Ractor.new
    #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
    #   result.output  # => 6
    #
    # @example With tools
    #   executor = Executors::Ractor.new
    #   executor.send_tools("search" => search_tool)
    #   result = executor.execute('search(query: "Ruby")', language: :ruby)
    #
    # @example Handling shared data
    #   executor = Executors::Ractor.new
    #   executor.send_variables({
    #     "numbers" => [1, 2, 3],
    #     "api_key" => "secret"  # Will be frozen for Ractor
    #   })
    #
    # @see Executor Base class for resource limits
    # @see IsolatedSandbox For simple execution without tools
    # @see ToolSandbox For message-based tool execution
    class Ractor < Executor
      # Creates a new Ractor executor.
      #
      # Initializes with resource limits. Ractor uses the parent Executor's
      # max_operations and max_output_length settings. Trace mode is fixed to
      # :line (TracePoint only supports :line in Ractor context).
      #
      # @param max_operations [Integer] Maximum operations before timeout
      #   (default: DEFAULT_MAX_OPERATIONS = 100,000)
      # @param max_output_length [Integer] Maximum output bytes to capture
      #   (default: DEFAULT_MAX_OUTPUT_LENGTH = 50,000)
      # @return [void]
      # @example
      #   executor = Executors::Ractor.new(max_operations: 50_000)
      def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH)
        super
      end

      # Executes Ruby code in an isolated Ractor.
      #
      # Selects optimal execution strategy based on whether tools are registered:
      # - No tools: Simple isolated execution in a Ractor
      # - With tools: Message-based execution with tool support
      #
      # The timeout parameter is accepted for API compatibility. Execution
      # is bounded by operation limits via TracePoint.
      #
      # == Execution Flow
      # 1. Validate code and language (must be :ruby)
      # 2. Validate Ruby safety (pattern-based checks)
      # 3. Select execution strategy (isolated or tool-supporting)
      # 4. Create Ractor with code and variables
      # 5. Wait for result or handle tool calls
      #
      # @param code [String] Ruby code to execute
      # @param language [Symbol] Must be :ruby
      # @param timeout [Integer] Accepted for API compatibility (not used).
      #   Operation limits via TracePoint provide the actual bound.
      # @param options [Hash] Additional options (ignored)
      # @return [ExecutionResult] Result with output, logs, and any error
      # @example
      #   executor = Executors::Ractor.new
      #   result = executor.execute("[1,2,3].map { |x| x ** 2 }", language: :ruby)
      #   result.output  # => [1, 4, 9]
      #
      # @example With tools
      #   executor = Executors::Ractor.new
      #   executor.send_tools("query" => db_query_tool)
      #   result = executor.execute('query(sql: "SELECT * FROM users")', language: :ruby)
      # @see IsolatedSandbox For tool-free execution
      # @see ToolSandbox For tool-supporting execution
      # @see prepare_for_ractor For Ractor boundary crossing
      def execute(code, language: :ruby, timeout: nil, **_options)
        Instrumentation.instrument("smolagents.executor.execute", executor_class: self.class.name, language:) do
          validate_execution_params!(code, language)
          validate_ruby_code!(code)

          if tools.empty?
            execute_in_ractor_isolated(code)
          else
            execute_with_tool_support(code)
          end
        rescue InterpreterError => e
          build_result(nil, "", error: e.message)
        end
      end

      # Checks if Ractor executor supports a language.
      #
      # Ractor only supports Ruby.
      #
      # @param language [Symbol] Language to check
      # @return [Boolean] True only if language is :ruby
      # @example
      #   executor = Executors::Ractor.new
      #   executor.supports?(:ruby)    # => true
      #   executor.supports?(:python)  # => false
      def supports?(language) = language.to_sym == :ruby

      # Maximum message iterations before returning error (prevents runaway).
      #
      # When tools are in use, the main Ractor processes tool call messages
      # from the execution Ractor. This limit prevents infinite message loops
      # if code gets stuck in a tool call loop.
      #
      # @return [Integer] Maximum iterations (10,000)
      MAX_MESSAGE_ITERATIONS = 10_000

      # Builds a TracePoint that limits execution operations (for Ractor sandboxing).
      # Class method so it can be called from within Ractor blocks.
      def self.build_operation_limiter(max_operations)
        operations = 0
        TracePoint.new(:line) do |tp|
          operations += 1
          next unless operations > max_operations

          tp.disable
          Thread.current.raise("Operation limit exceeded: #{max_operations}")
        end
      end

      private

      # Executes code in an isolated Ractor without tool support.
      #
      # Simplest execution path when no tools are registered. Variables are
      # copied and frozen for Ractor boundary crossing.
      #
      # @param code [String] Ruby code to execute
      # @return [ExecutionResult] Execution result
      # @raise [Ractor::RemoteError] If Ractor execution raises an error
      # @api private
      def execute_in_ractor_isolated(code)
        ractor = create_isolated_ractor(code)
        wait_for_ractor_result(ractor)
      rescue ::Ractor::RemoteError => e
        handle_ractor_error(e)
      end

      # Creates an isolated Ractor for code execution.
      #
      # Spawns a new Ractor with code and prepared variables. The Ractor runs
      # in complete isolation with its own memory space. Returns a Ractor
      # instance that can be waited on for results.
      #
      # == Ractor Initialization
      # The Ractor receives: code_str, max_operations, vars (frozen/serialized)
      # It returns: { output, logs, error, is_final }
      #
      # @param code [String] Ruby code to execute
      # @return [::Ractor] A running Ractor instance
      # @api private
      def create_isolated_ractor(code)
        ::Ractor.new(code, max_operations, prepare_variables) do |code_str, max_ops, vars|
          output_buffer = StringIO.new
          trace = Smolagents::Executors::RactorExecutor.build_operation_limiter(max_ops)
          sandbox = IsolatedSandbox.new(variables: vars, output_buffer:)

          trace.enable
          result = sandbox.instance_eval(code_str)
          { output: result, logs: output_buffer.string, error: nil, is_final: false }
        rescue StandardError => e
          { output: nil, logs: output_buffer.string, error: "#{e.class}: #{e.message}", is_final: false }
        ensure
          trace&.disable
        end
      end

      # Waits for a Ractor to complete and returns its result.
      #
      # Blocks until the Ractor finishes execution and returns its value.
      # The Ractor's return value is a hash with execution details.
      #
      # @param ractor [::Ractor] A running Ractor instance
      # @return [ExecutionResult] The execution result
      # @api private
      def wait_for_ractor_result(ractor)
        result = ractor.value
        build_result(result[:output], result[:logs], error: result[:error], is_final: result[:is_final])
      end

      # Handles errors from Ractor execution.
      #
      # Extracts error information from a Ractor::RemoteError and builds
      # a failed ExecutionResult.
      #
      # @param err [::Ractor::RemoteError] Error from Ractor
      # @return [ExecutionResult] Failed result with error message
      # @api private
      def handle_ractor_error(err)
        build_result(nil, "", error: "Ractor error: #{err.cause&.message || err.message}")
      end

      # Executes code in a Ractor with tool support via message passing.
      #
      # Creates a Ractor that can make tool calls back to the main Ractor.
      # The tool call mechanism uses message passing through Ractor.send/receive.
      #
      # @param code [String] Ruby code to execute
      # @return [ExecutionResult] Execution result (may include tool call messages)
      # @raise [Ractor::RemoteError] If Ractor execution raises an error
      # @api private
      def execute_with_tool_support(code)
        child_ractor = create_tool_ractor(code)
        wait_for_tool_ractor_result(child_ractor)
      rescue ::Ractor::RemoteError => e
        handle_ractor_error(e)
      end

      # Creates a Ractor with tool call support via message passing.
      #
      # Spawns a Ractor that can call tools by sending messages back to the main
      # Ractor. The main Ractor receives tool call messages, executes the tools,
      # and sends results back to the child Ractor.
      #
      # == Message Protocol
      # - Child to Main: { type: :tool_call, name, args, kwargs, caller_ractor }
      # - Main to Child: { result: value } or { final_answer: value } or { error: message }
      #
      # @param code [String] Ruby code to execute
      # @return [::Ractor] A running Ractor instance
      # @api private
      def create_tool_ractor(code)
        ::Ractor.new(code, max_operations, tools.keys.freeze, prepare_variables) do |code_str, max_ops, tools_list, vars|
          output_buffer = StringIO.new
          trace = Smolagents::Executors::RactorExecutor.build_operation_limiter(max_ops)
          sandbox = ToolSandbox.new(tool_names: tools_list, variables: vars, output_buffer:)

          trace.enable
          result = sandbox.instance_eval(code_str)
          ::Ractor.main.send({ type: :result, output: result, logs: output_buffer.string, error: nil, is_final: false })
        rescue FinalAnswerSignal => e
          ::Ractor.main.send({ type: :result, output: e.value, logs: output_buffer.string, error: nil, is_final: true })
        rescue StandardError => e
          ::Ractor.main.send({ type: :result, output: nil, logs: output_buffer.string, error: "#{e.class}: #{e.message}", is_final: false })
        ensure
          trace&.disable
        end
      end

      # Waits for tool Ractor result, processing tool call messages.
      #
      # Blocks while processing messages from the child Ractor. Each tool call
      # message is handled by executing the tool and sending the result back.
      # Returns when the child sends a :result message.
      #
      # @param child_ractor [::Ractor] The child Ractor instance
      # @return [ExecutionResult] The final execution result
      # @api private
      def wait_for_tool_ractor_result(child_ractor)
        result = process_messages(child_ractor)
        build_result(result[:output], result[:logs], error: result[:error], is_final: result[:is_final])
      end

      # Processes messages from child Ractor until completion.
      #
      # Main loop handling all messages from the child Ractor. Dispatches to
      # handle_tool_call for tool invocations and returns when receiving :result.
      # Limits iterations to prevent infinite loops.
      #
      # == Message Types
      # - :result - Execution complete, return the data
      # - :tool_call - Tool invocation, execute and send back response
      #
      # @param _child_ractor [::Ractor] Child Ractor (for documentation)
      # @return [Hash] Result hash with :output, :logs, :error, :is_final keys
      # @api private
      def process_messages(_child_ractor)
        MAX_MESSAGE_ITERATIONS.times do
          message = ::Ractor.receive

          case message
          in { type: :result, **data }
            return data
          in { type: :tool_call, name: tool_name, args:, kwargs:, caller_ractor: }
            response = handle_tool_call(tool_name, args, kwargs)
            caller_ractor.send(response)
          end
        end

        # Exceeded max iterations without receiving result
        { output: nil, logs: "", error: "Message processing limit exceeded", is_final: false }
      end

      # Handles a tool call message from child Ractor.
      #
      # Executes the requested tool and returns a response message. The response
      # contains either:
      # - { result: value } - Tool executed successfully
      # - { final_answer: value } - Tool raised FinalAnswerException
      # - { error: message } - Tool execution failed
      #
      # Tool results are prepared for Ractor boundary crossing via prepare_for_ractor.
      #
      # @param tool_name [String] Name of the tool to invoke
      # @param args [Array] Positional arguments for the tool
      # @param kwargs [Hash] Keyword arguments for the tool
      # @return [Hash] Response message for the child Ractor
      # @api private
      def handle_tool_call(tool_name, args, kwargs)
        tool = tools[tool_name]
        return { error: "Unknown tool: #{tool_name}" } unless tool

        begin
          result = tool.call(*args, **kwargs)
          { result: prepare_for_ractor(result) }
        rescue FinalAnswerException => e
          { final_answer: prepare_for_ractor(e.value) }
        rescue StandardError => e
          { error: "#{e.class}: #{e.message}" }
        end
      end

      # Kills a Ractor (cleanup).
      #
      # Safely closes a Ractor instance, ignoring errors. This is a defensive
      # measure for resource cleanup.
      #
      # @param ractor [::Ractor, nil] Ractor to close
      # @return [void]
      # @api private
      def ractor_kill(ractor)
        return unless ractor

        ractor.close if ractor.respond_to?(:close)
      rescue StandardError
        # Ignore errors when killing
      end

      # Prepares variables for Ractor boundary crossing.
      #
      # Transforms all variables to make them shareable (or JSON-compatible).
      # Uses prepare_for_ractor on each value.
      #
      # @return [Hash{String => Object}] Variables safe for Ractor
      # @api private
      def prepare_variables
        variables.transform_values { |val| prepare_for_ractor(val) }
      end

      # Prepares an object for Ractor boundary crossing.
      #
      # Converts objects to shareable form (frozen or serialized). This is essential
      # for passing data between Ractors, which have strict shareability rules.
      #
      # == Shareability Rules
      #
      # Objects that can cross Ractor boundaries:
      # - Primitives (Integer, Float, Symbol, nil, true, false) - always shareable
      # - Frozen strings - shareable by reference (duplicated and frozen if not already)
      # - Frozen arrays - shareable if all contents are shareable (recursively frozen)
      # - Frozen hashes - shareable if all keys and values are shareable (frozen)
      # - Data.define instances - shareable when ALL field values are shareable
      #   (Note: custom methods in the Data.define block do NOT affect shareability)
      #
      # Objects that cannot cross (converted):
      # - Procs, Lambdas - NEVER shareable, converted to strings
      # - Arbitrary objects - converted to hash (to_h) or array (to_a) if possible
      # - Everything else - converted to frozen string representation
      #
      # == Conversion Strategy
      #
      # 1. Primitives and already-shareable objects pass through
      # 2. Strings are frozen (or dup+freeze)
      # 3. Collections (Array, Hash) have all contents recursively prepared
      # 4. Check if object is already shareable via ::Ractor.shareable?
      # 5. Fall back to safe_serialize_for_ractor for complex objects
      #
      # @param obj [Object] Object to prepare for Ractor boundary
      # @return [Object] Shareable representation of the object
      # @api private
      def prepare_for_ractor(obj)
        case obj
        when NilClass, TrueClass, FalseClass, Integer, Float, Symbol
          obj
        when String
          obj.frozen? ? obj : obj.dup.freeze
        when Array
          obj.map { |item| prepare_for_ractor(item) }.freeze
        when Hash
          obj.transform_keys { |key| prepare_for_ractor(key) }
             .transform_values { |val| prepare_for_ractor(val) }
             .freeze
        else
          return obj if ::Ractor.shareable?(obj)

          # Use JSON instead of Marshal for safety (avoids deserialization attacks)
          # Complex objects are converted to their hash representation
          safe_serialize_for_ractor(obj)
        end
      end

      # Safely serializes non-shareable objects for Ractor boundaries.
      #
      # Attempts intelligent conversion of objects that aren't natively shareable:
      # 1. Range/Set → to_a (enumerable form)
      # 2. Struct/Data → to_h (structural representation)
      # 3. Objects with to_h → to_h (prefer hash over array)
      # 4. Objects with to_a → to_a (fallback to array)
      # 5. Everything else → to_s.freeze (string representation)
      #
      # All results are recursively prepared via prepare_for_ractor to ensure
      # nested structures are fully shareable.
      #
      # @param obj [Object] Non-shareable object to serialize
      # @return [Object] Shareable serialized form
      # @api private
      def safe_serialize_for_ractor(obj)
        case obj
        when Range, Set
          # Pure enumerables without meaningful to_h
          prepare_for_ractor(obj.to_a)
        when Struct, Data
          # Struct-like objects should use to_h
          prepare_for_ractor(obj.to_h)
        else
          # Try to_h first for objects with hash representation
          if obj.respond_to?(:to_h) && !obj.is_a?(Array)
            prepare_for_ractor(obj.to_h)
          elsif obj.respond_to?(:to_a)
            prepare_for_ractor(obj.to_a)
          else
            # Last resort: convert to string representation
            obj.to_s.freeze
          end
        end
      end

      # Signal for final answer in Ractor context.
      #
      # Used instead of FinalAnswerException in Ractor context because exceptions
      # cannot be safely passed across Ractor boundaries. This custom signal is
      # caught and handled to trigger final answer behavior.
      #
      # @example
      #   raise FinalAnswerSignal, "The answer is 42"
      #
      # @see FinalAnswerException For LocalRuby context
      class FinalAnswerSignal < StandardError
        # The final answer value.
        #
        # @return [Object] The value passed to the signal
        attr_reader :value

        # Creates a new FinalAnswerSignal.
        #
        # @param value [Object] The final answer value
        # @return [void]
        def initialize(value)
          @value = value
          super("Final answer")
        end
      end

      # Sandbox for isolated Ractor execution without tools.
      #
      # A minimal execution environment for code running in a Ractor without
      # tool support. Extends BasicObject to minimize available methods.
      # Only variables are accessible (no tools).
      #
      # == Method Resolution
      #
      # Unknown methods are handled by method_missing:
      # 1. Check if name is a registered variable → return its value
      # 2. Handle safe built-in methods (puts, print, p, rand, etc.)
      # 3. Otherwise raise NoMethodError
      #
      # @see ToolSandbox For tool-supporting version
      # @api private
      class IsolatedSandbox < ::BasicObject
        # Creates a new isolated sandbox.
        #
        # @param variables [Hash{String => Object}] Accessible variables
        # @param output_buffer [StringIO] Buffer for stdout capture
        # @return [void]
        def initialize(variables:, output_buffer:)
          @variables = variables
          @output_buffer = output_buffer
        end

        # Routes unknown methods to variables or safe built-ins.
        #
        # @param name [Symbol] Method name
        # @param _args [Array] Arguments (ignored)
        # @param _kwargs [Hash] Keyword arguments (ignored)
        # @return [Object] Variable value or method result
        # @raise [NoMethodError] If method not found
        # @api private
        def method_missing(name, *_args, **_kwargs)
          name_str = name.to_s
          if @variables.key?(name_str)
            @variables[name_str]
          else
            case name
            when :nil? then false
            when :class then ::Object
            else
              ::Kernel.raise(::NoMethodError, "undefined method `#{name}' in sandbox")
            end
          end
        end

        # Reports available methods.
        #
        # @param name [Symbol] Method name to check
        # @param _ [Boolean] Include parameter (ignored)
        # @return [Boolean] True if name is a registered variable
        # @api private
        def respond_to_missing?(name, _ = false)
          @variables.key?(name.to_s)
        end

        # Outputs a line to the captured output buffer.
        # @api private
        def puts(*) = @output_buffer.puts(*) || nil

        # Outputs text without newline to the captured output buffer.
        # @api private
        def print(*) = @output_buffer.print(*) || nil

        # Inspects objects and outputs them to the captured output buffer.
        # @api private
        def p(*args) = @output_buffer.puts(args.map(&:inspect).join(", ")) || (args.length <= 1 ? args.first : args)

        # Random number generator (delegates to ::Kernel).
        # @param max [Integer, nil] Maximum value (optional)
        # @return [Float, Integer] Random number
        # @api private
        def rand(max = nil) = max ? ::Kernel.rand(max) : ::Kernel.rand

        # Returns the variables hash for debugging.
        # @return [Hash{String => Object}] Variables
        # @api private
        def state = @variables

        # Type checking (always false in sandbox).
        # @api private
        def is_a?(_) = false

        # Type checking (always false in sandbox).
        # @api private
        def kind_of?(_) = false

        # Equality check (only true for same object).
        # @api private
        def ==(other) = equal?(other)

        # Inequality check (opposite of ==).
        # @api private
        def !=(other) = !equal?(other)

        # Define raise and loop via define_method to avoid method_missing
        define_method(:raise) { |*args| ::Kernel.raise(*args) }
        define_method(:loop) { |&block| ::Kernel.loop(&block) }
      end

      # Sandbox for Ractor execution with tool support via message passing.
      #
      # Execution environment for code that calls tools. Tool calls are routed
      # via message passing to the main Ractor, which executes the tools and
      # sends results back.
      #
      # == Method Resolution
      #
      # Unknown methods are handled by method_missing:
      # 1. Check if name is a tool → send tool_call message to main Ractor
      # 2. Check if name is a variable → return its value
      # 3. Handle safe built-in methods (puts, print, p, rand, etc.)
      # 4. Otherwise raise NoMethodError
      #
      # == Tool Call Protocol
      #
      # - Child Ractor: Sends message { type: :tool_call, name, args, kwargs, caller_ractor }
      # - Main Ractor: Receives message, executes tool
      # - Main Ractor: Sends back { result: value } or { error: message }
      # - Child Ractor: Receives and returns/raises appropriately
      #
      # @see IsolatedSandbox For tool-free version
      # @api private
      class ToolSandbox < ::BasicObject
        # Creates a new tool-supporting sandbox.
        #
        # @param tool_names [Array<String>] Names of available tools
        # @param variables [Hash{String => Object}] Accessible variables
        # @param output_buffer [StringIO] Buffer for stdout capture
        # @return [void]
        def initialize(tool_names:, variables:, output_buffer:)
          @tool_names = tool_names
          @variables = variables
          @output_buffer = output_buffer
        end

        # Routes unknown methods to tools, variables, or safe built-ins.
        #
        # @param name [Symbol] Method name
        # @param args [Array] Positional arguments for tools
        # @param kwargs [Hash] Keyword arguments for tools
        # @return [Object] Tool result, variable value, or method result
        # @raise [NoMethodError] If method not found
        # @api private
        def method_missing(name, *args, **kwargs)
          name_str = name.to_s
          if @tool_names.include?(name_str)
            call_tool(name_str, args, kwargs)
          elsif @variables.key?(name_str)
            @variables[name_str]
          else
            case name
            when :nil? then false
            when :class then ::Object
            else
              ::Kernel.raise(::NoMethodError, "undefined method `#{name}' in sandbox")
            end
          end
        end

        # Reports available methods.
        #
        # @param name [Symbol] Method name to check
        # @param _ [Boolean] Include parameter (ignored)
        # @return [Boolean] True if name is a tool or variable
        # @api private
        def respond_to_missing?(name, _ = false)
          name_str = name.to_s
          @tool_names.include?(name_str) || @variables.key?(name_str)
        end

        # Outputs a line to the captured output buffer.
        # @api private
        def puts(*) = @output_buffer.puts(*) || nil

        # Outputs text without newline to the captured output buffer.
        # @api private
        def print(*) = @output_buffer.print(*) || nil

        # Inspects objects and outputs them to the captured output buffer.
        # @api private
        def p(*args) = @output_buffer.puts(args.map(&:inspect).join(", ")) || (args.length <= 1 ? args.first : args)

        # Random number generator (delegates to ::Kernel).
        # @param max [Integer, nil] Maximum value (optional)
        # @return [Float, Integer] Random number
        # @api private
        def rand(max = nil) = max ? ::Kernel.rand(max) : ::Kernel.rand

        # Returns the variables hash for debugging.
        # @return [Hash{String => Object}] Variables
        # @api private
        def state = @variables

        # Type checking (always false in sandbox).
        # @api private
        def is_a?(_) = false

        # Type checking (always false in sandbox).
        # @api private
        def kind_of?(_) = false

        # Equality check (only true for same object).
        # @api private
        def ==(other) = equal?(other)

        # Inequality check (opposite of ==).
        # @api private
        def !=(other) = !equal?(other)

        # Define raise and loop via define_method to avoid method_missing
        define_method(:raise) { |*args| ::Kernel.raise(*args) }
        define_method(:loop) { |&block| ::Kernel.loop(&block) }

        private

        # Calls a tool via message passing to the main Ractor.
        #
        # Sends a tool call message to the main Ractor, waits for response,
        # and returns/raises based on the result.
        #
        # == Response Handling
        # - { result: value } → Return value
        # - { final_answer: value } → Raise FinalAnswerSignal
        # - { error: message } → Raise RuntimeError
        #
        # @param name [String] Tool name
        # @param args [Array] Positional arguments
        # @param kwargs [Hash] Keyword arguments
        # @return [Object] Tool result
        # @raise [FinalAnswerSignal] If tool raises FinalAnswerException
        # @raise [RuntimeError] If tool execution fails
        # @api private
        def call_tool(name, args, kwargs)
          current = ::Ractor.current
          ::Ractor.main.send({
                               type: :tool_call,
                               name:,
                               args:,
                               kwargs:,
                               caller_ractor: current
                             })
          response = ::Ractor.receive

          case response
          in { result: value }
            value
          in { final_answer: value }
            ::Kernel.raise(FinalAnswerSignal, value)
          in { error: message }
            ::Kernel.raise(::RuntimeError, message)
          end
        end
      end
    end
  end
end
