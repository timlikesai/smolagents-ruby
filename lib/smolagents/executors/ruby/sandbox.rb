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
          @defined_vars = []
        end

        # Returns variables defined during this execution.
        # @return [Array<String>] Names of variables defined via assignment
        def defined_variables = @defined_vars

        # Routes unknown methods to tools, variables, or raises NoMethodError.
        #
        # Implements method routing for the sandbox environment:
        # 1. If name ends with =, stores value in variables (for persistence)
        # 2. If name is a registered tool, calls it with provided arguments
        # 3. If name is a registered variable, returns its value
        # 4. Otherwise delegates to sandbox_fallback (raises NoMethodError)
        #
        # @param name [Symbol] Method name (becomes a string for lookup)
        # @param args [Array] Positional arguments (passed to tools)
        # @param kwargs [Hash] Keyword arguments (passed to tools)
        # @return [Object] Tool result, variable value, or raises
        # @raise [NoMethodError] If method not found in tools/variables
        # @api private
        def method_missing(name, *args, **)
          name_str = name.to_s
          return store_variable(name_str, args.first) if name_str.end_with?("=")
          return @tools[name_str].call(*args, **) if @tools.key?(name_str)
          return @variables[name_str] if @variables.key?(name_str)

          Sandbox.sandbox_fallback(name)
        end

        private

        # Stores a variable for persistence between code blocks.
        # @param name [String] Variable name with trailing =
        # @param value [Object] Value to store
        # @return [Object] The stored value
        def store_variable(name, value)
          var_name = name.chomp("=")
          @variables[var_name] = value
          @defined_vars << var_name unless @defined_vars.include?(var_name)
          value
        end

        # Reports which methods are available to respond_to?.
        #
        # @param name [Symbol] Method name to check
        # @param _include_all [Boolean] Ignored
        # @return [Boolean] True if name is a tool, variable, or setter pattern
        # @api private
        def respond_to_missing?(name, _include_all = false)
          name_str = name.to_s
          name_str.end_with?("=") || @tools.key?(name_str) || @variables.key?(name_str)
        end
      end
    end
  end
end
