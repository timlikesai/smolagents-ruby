require_relative "sandbox"
require_relative "final_answer_signal"

module Smolagents
  module Executors
    # Sandbox for Ractor execution with tool support via message passing.
    #
    # Tool calls are routed via Ractor message passing to the main Ractor,
    # which executes the tools and sends results back.
    #
    # == Tool Call Protocol
    #
    # - Child Ractor: Sends { type: :tool_call, name, args, kwargs, caller_ractor }
    # - Main Ractor: Receives, executes tool, sends back response
    # - Child Ractor: Receives { result: } or { final_answer: } or { error: }
    #
    # @see IsolatedSandbox For tool-free version
    # @see Sandbox Base class with shared behavior
    # @api private
    class ToolSandbox < Sandbox
      # @param tool_names [Array<String>] Names of available tools
      # @param variables [Hash{String => Object}] Accessible variables
      # @param output_buffer [StringIO] Buffer for stdout capture
      def initialize(tool_names:, variables:, output_buffer:)
        super(variables:, output_buffer:)
        @tool_names = tool_names
      end

      # Routes unknown methods to tools, variables, or raises NoMethodError.
      #
      # @param name [Symbol] Method name
      # @param args [Array] Positional arguments for tools
      # @param kwargs [Hash] Keyword arguments for tools
      # @return [Object] Tool result or variable value
      # @raise [NoMethodError] If method not found
      # @api private
      def method_missing(name, *args, **kwargs)
        name_str = name.to_s
        return call_tool(name_str, args, kwargs) if @tool_names.include?(name_str)
        return @variables[name_str] if @variables.key?(name_str)

        handle_unknown_method(name)
      end

      # @api private
      def respond_to_missing?(name, _ = false)
        name_str = name.to_s
        @tool_names.include?(name_str) || @variables.key?(name_str)
      end

      private

      # Calls a tool via message passing to the main Ractor.
      # @api private
      def call_tool(name, args, kwargs)
        ::Ractor.main.send({ type: :tool_call, name:, args:, kwargs:, caller_ractor: ::Ractor.current })
        handle_tool_response(::Ractor.receive)
      end

      def handle_tool_response(response)
        case response
        in { result: value } then value
        in { final_answer: value } then ::Kernel.raise(FinalAnswerSignal, value)
        in { error: message } then ::Kernel.raise(::RuntimeError, message)
        end
      end
    end
  end
end
