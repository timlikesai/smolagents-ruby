module Smolagents
  module Tools
    class Tool
      # Tool execution logic including call, setup, result wrapping, and control flow.
      module Execution
        # Thread-local key for fiber context detection.
        FIBER_CONTEXT_KEY = :smolagents_fiber_context

        # Request user input during tool execution.
        #
        # In fiber context, yields a UserInput control request and waits for response.
        # Outside fiber context, returns the default value immediately.
        #
        # @param prompt [String] The prompt to display to the user
        # @param options [Array<String>, nil] Optional list of valid choices
        # @param default_value [Object, nil] Value to return in non-fiber context
        # @param timeout [Integer, nil] Optional timeout in seconds
        # @return [Object] User's response or default value
        def request_input(prompt, options: nil, default_value: nil, timeout: nil)
          return default_value unless fiber_context?

          request = Types::ControlRequests::UserInput.create(
            prompt:, options:, default_value:, timeout:
          )
          Fiber.yield(request)&.value || default_value
        end

        # Request confirmation before executing a potentially dangerous action.
        #
        # In fiber context, yields a Confirmation control request and waits for response.
        # Outside fiber context, auto-approves if reversible, otherwise returns false.
        #
        # @param action [String] The action being confirmed
        # @param description [String] Human-readable description of the action
        # @param consequences [Array<String>] List of potential consequences
        # @param reversible [Boolean] Whether the action can be undone
        # @return [Boolean] True if approved, false if denied
        def request_confirmation(action:, description:, consequences: [], reversible: true)
          return reversible unless fiber_context?

          request = Types::ControlRequests::Confirmation.create(
            action:, description:, consequences:, reversible:
          )
          Fiber.yield(request)&.approved? || false
        end

        private

        # Check if we're running in a fiber context with control flow enabled.
        # @return [Boolean]
        def fiber_context? = Thread.current[FIBER_CONTEXT_KEY] == true

        public

        # Invokes the tool with the given arguments.
        #
        # @param args [Array] Positional arguments (single Hash is converted to kwargs)
        # @param sanitize_inputs_outputs [Boolean] Reserved for input/output sanitization
        # @param wrap_result [Boolean] Whether to wrap result in ToolResult
        # @param context [Hash] Execution context (model_id, agent_type, etc.)
        # @param kwargs [Hash] Keyword arguments matching the inputs specification
        # @return [ToolResult, Object] Wrapped or raw result
        def call(*args, _sanitize_inputs_outputs: false, wrap_result: true, context: {}, **kwargs)
          Telemetry::Instrumentation.instrument("smolagents.tool.call", instrument_attrs(args, kwargs, context)) do
            setup unless @initialized
            result, final_kwargs = execute_with_args(args, kwargs)
            wrap_result ? wrap_in_tool_result(result, build_result_metadata(args, final_kwargs)) : result
          end
        end

        # Executes the tool's core logic. Subclasses must override.
        #
        # @param kwargs [Hash] Keyword arguments
        # @return [Object] The tool's output
        # @raise [NotImplementedError] if not overridden
        def execute(**_kwargs) = raise(NotImplementedError, "#{self.class}#execute must be implemented")

        # Performs one-time initialization.
        # @return [Boolean]
        def setup = @initialized = true

        # @return [Boolean] true if setup has been called
        def initialized? = @initialized

        private

        def execute_with_args(args, kwargs)
          # Determine how to call execute based on argument style
          hash_as_arg = args.length == 1 && kwargs.empty? && args.first.is_a?(Hash)
          final_kwargs = hash_as_arg ? symbolize_keys(args.first) : symbolize_keys(kwargs)
          final_args = hash_as_arg ? [] : args # Clear args if converted to kwargs

          result = execute_with_error_hints(final_args, final_kwargs)
          [result, final_kwargs]
        end

        def execute_with_error_hints(args, kwargs)
          if args.empty?
            execute(**kwargs)
          else
            execute(*args, **kwargs)
          end
        rescue TypeError, ArgumentError, ZeroDivisionError, NameError => e # NameError includes NoMethodError
          # Enhance common errors with helpful hints, passing expected inputs for better messages
          raise ErrorHints.enhance_error(e, tool_name: name, inputs: kwargs, expected_inputs: inputs)
        end

        def symbolize_keys(hash)
          hash.transform_keys { |k| k.respond_to?(:to_sym) ? k.to_sym : k }
        end

        def wrap_in_tool_result(result, inputs)
          return result if result.is_a?(ToolResult)

          metadata = { inputs:, output_type: }
          if result.is_a?(String) && result.start_with?("Error", "An unexpected error")
            ToolResult.error(StandardError.new(result), tool_name: name, metadata:)
          else
            ToolResult.new(result, tool_name: name, metadata:)
          end
        end

        def build_result_metadata(args, kwargs)
          metadata = kwargs.dup
          metadata[:args] = args unless args.empty?
          metadata
        end

        def instrument_attrs(args, kwargs, context)
          {
            tool_name: name,
            tool_class: self.class.name,
            argument_style: detect_arg_style(args, kwargs),
            argument_count: args.length + kwargs.length,
            model_id: context[:model_id],
            agent_type: context[:agent_type]
          }
        end

        def detect_arg_style(args, kwargs)
          case [args, kwargs]
          in [[Hash], {}] then :hash
          in [[], {}] then :none
          in [_, {}] then :positional
          in [[], _] then :keyword
          else :mixed
          end
        end
      end
    end
  end
end
