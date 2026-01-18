module Smolagents
  module Executors
    class LocalRuby < Executor
      # Restricted execution environment based on BasicObject.
      #
      # Sandbox is a minimal execution environment extending BasicObject instead of Object.
      # This removes access to Kernel, Object, and their methods. Only explicitly
      # registered tools and variables are accessible.
      #
      # == Design
      #
      # By extending BasicObject instead of Object, the sandbox starts with almost
      # no methods available. This minimizes the attack surface - agent code cannot
      # access File, IO, Process, or other dangerous Ruby classes.
      #
      # == Method Resolution
      #
      # Unknown methods are routed via method_missing:
      # 1. Check if name matches a registered tool -> call it with arguments
      # 2. Check if name matches a registered variable -> return its value
      # 3. Check for safe methods (puts, print, p, rand)
      # 4. Fallback to sandbox_fallback for error handling
      #
      # == Output Capture
      #
      # The output_buffer (StringIO) captures all puts/print calls, making
      # stdout visible in the ExecutionResult.
      #
      # == Available Safe Methods
      #
      # - `puts`, `print`, `p` - Output capture
      # - `rand` - Random number generation
      # - `tools` - List available tools
      # - `vars` - List available variables
      # - `help(tool_name)` - Get tool help
      #
      # @api private
      # @see Concerns::SandboxMethods For method definitions
      class Sandbox < ::BasicObject
        Concerns::SandboxMethods.define_on(self)

        # Creates a new sandbox with registered tools and variables.
        #
        # @param tools [Hash{String => Tool}] Callable tools by name
        # @param variables [Hash{String => Object}] Accessible variables by name
        # @param output_buffer [StringIO] Buffer for stdout capture
        # @return [void]
        def initialize(tools:, variables:, output_buffer:)
          @tools = tools
          @variables = variables
          @output_buffer = output_buffer
        end

        # Routes unknown methods to tools, variables, or raises NoMethodError.
        #
        # Implements method routing for the sandbox environment:
        # 1. If name is a registered tool, calls it with provided arguments
        # 2. If name is a registered variable, returns its value
        # 3. Otherwise delegates to sandbox_fallback (raises NoMethodError)
        #
        # @param name [Symbol] Method name (becomes a string for lookup)
        # @param args [Array] Positional arguments (passed to tools)
        # @param kwargs [Hash] Keyword arguments (passed to tools)
        # @return [Object] Tool result, variable value, or raises
        # @raise [NoMethodError] If method not found in tools/variables
        # @api private
        def method_missing(name, *, **)
          name_str = name.to_s
          return @tools[name_str].call(*, **) if @tools.key?(name_str)
          return @variables[name_str] if @variables.key?(name_str)

          Sandbox.sandbox_fallback(name)
        end

        # Reports which methods are available to respond_to?.
        #
        # @param name [Symbol] Method name to check
        # @param _include_all [Boolean] Ignored
        # @return [Boolean] True if name is a registered tool or variable
        # @api private
        def respond_to_missing?(name, _include_all = false) = @tools.key?(name.to_s) || @variables.key?(name.to_s)
      end
    end
  end
end
