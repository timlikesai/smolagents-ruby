require "forwardable"

module Smolagents
  # Base class for all tools in the smolagents framework.
  #
  # Tools are the building blocks that agents use to interact with the world.
  # Each tool encapsulates a specific capability (search, read files, call APIs,
  # etc.) and exposes it through a standardized interface that agents can discover
  # and invoke.
  #
  # The Tool class provides:
  # - Declarative metadata (name, description, inputs, output_type) for agent discovery
  # - Automatic input validation
  # - Result wrapping in {ToolResult} for chainable operations
  # - Lazy initialization via {#setup}
  # - Multiple prompt formats for different agent types
  #
  # @example Subclassing to create a simple tool
  #   class GreetingTool < Smolagents::Tool
  #     self.tool_name = "greet"
  #     self.description = "Generate a personalized greeting message"
  #     self.inputs = {
  #       name: { type: "string", description: "The name of the person to greet" },
  #       formal: { type: "boolean", description: "Use formal greeting style", nullable: true }
  #     }
  #     self.output_type = "string"
  #
  #     def execute(name:, formal: false)
  #       formal ? "Good day, #{name}." : "Hello, #{name}!"
  #     end
  #   end
  #
  #   tool = GreetingTool.new
  #   result = tool.call(name: "Alice")
  #   result.data  # => "Hello, Alice!"
  #
  # @example Tool with structured output schema
  #   class WeatherTool < Smolagents::Tool
  #     self.tool_name = "get_weather"
  #     self.description = "Get current weather for a location"
  #     self.inputs = {
  #       location: { type: "string", description: "City name or coordinates" }
  #     }
  #     self.output_type = "object"
  #     self.output_schema = {
  #       temperature: "number",
  #       conditions: "string",
  #       humidity: "number"
  #     }
  #
  #     def execute(location:)
  #       # Fetch weather data from API
  #       { temperature: 72, conditions: "sunny", humidity: 45 }
  #     end
  #   end
  #
  # @example Tool with setup for expensive initialization
  #   class DatabaseTool < Smolagents::Tool
  #     self.tool_name = "query_db"
  #     self.description = "Execute a database query"
  #     self.inputs = {
  #       sql: { type: "string", description: "SQL query to execute" }
  #     }
  #     self.output_type = "array"
  #
  #     def setup
  #       @connection = Database.connect(ENV["DATABASE_URL"])
  #       super  # Always call super to mark as initialized
  #     end
  #
  #     def execute(sql:)
  #       @connection.execute(sql).to_a
  #     end
  #   end
  #
  # @example Using the DSL alternative (Tools.define_tool)
  #   calculator = Smolagents::Tools.define_tool(
  #     "calculate",
  #     description: "Perform basic arithmetic",
  #     inputs: {
  #       expression: { type: "string", description: "Math expression to evaluate" }
  #     },
  #     output_type: "number"
  #   ) do |expression:|
  #     # Simple safe evaluation (production code should use a proper parser)
  #     eval(expression.gsub(/[^0-9+\-*\/().\s]/, ""))
  #   end
  #
  #   calculator.call(expression: "2 + 2").data  # => 4
  #
  # @example Tool with array input type
  #   class BatchProcessor < Smolagents::Tool
  #     self.tool_name = "batch_process"
  #     self.description = "Process multiple items in batch"
  #     self.inputs = {
  #       items: { type: "array", description: "Array of items to process" },
  #       operation: { type: "string", description: "Operation to apply" }
  #     }
  #     self.output_type = "array"
  #
  #     def execute(items:, operation:)
  #       items.map { |item| apply_operation(item, operation) }
  #     end
  #   end
  #
  # @example Accessing tool metadata for agent prompts
  #   tool = GreetingTool.new
  #   tool.name           # => "greet"
  #   tool.description    # => "Generate a personalized greeting message"
  #   tool.inputs         # => { name: { type: "string", ... }, ... }
  #   tool.output_type    # => "string"
  #   tool.to_h           # => { name: "greet", description: "...", ... }
  #
  # @see SearchTool Specialized base class for search tools with DSL
  # @see ToolResult Chainable result wrapper returned by {#call}
  # @see Tools.define_tool DSL for creating tools without subclassing
  # @see ToolCollection For grouping and managing multiple tools
  #
  class Tool
    extend Forwardable

    # Valid types for tool inputs and outputs.
    # These correspond to JSON Schema types with additions for media types.
    #
    # @return [Set<String>] Frozen set of valid type names
    AUTHORIZED_TYPES = Set.new(%w[string boolean integer number image audio array object any null]).freeze

    class << self
      # @!attribute [rw] tool_name
      #   The unique identifier for this tool. Used by agents to reference the tool.
      #   @return [String, nil] The tool name
      attr_accessor :tool_name

      # @!attribute [rw] description
      #   Human-readable description of what the tool does. Used in agent prompts
      #   to help agents understand when and how to use the tool.
      #   @return [String, nil] The tool description
      attr_accessor :description

      # @!attribute [rw] output_type
      #   The type of value returned by the tool. Must be one of {AUTHORIZED_TYPES}.
      #   @return [String] The output type (defaults to "any")
      attr_accessor :output_type

      # @!attribute [rw] output_schema
      #   Optional structured schema for complex output types. Used to generate
      #   more detailed documentation in agent prompts.
      #   @return [Hash, nil] The output schema
      attr_accessor :output_schema

      # @!attribute [r] inputs
      #   Hash describing each input parameter the tool accepts.
      #   @return [Hash{Symbol => Hash}] Input specifications
      attr_reader :inputs

      # Set the inputs hash, automatically symbolizing all keys.
      #
      # @param value [Hash] Input specifications
      # @return [Hash{Symbol => Hash}] Symbolized input specifications
      #
      # @example Input specification format
      #   self.inputs = {
      #     query: {
      #       type: "string",           # Required: one of AUTHORIZED_TYPES
      #       description: "Search query",  # Required: human-readable description
      #       nullable: true            # Optional: if true, parameter is optional
      #     }
      #   }
      def inputs=(value)
        @inputs = deep_symbolize_keys(value)
      end

      # @api private
      # Sets up default values for subclasses
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@tool_name, nil)
        subclass.instance_variable_set(:@description, nil)
        subclass.instance_variable_set(:@inputs, {})
        subclass.instance_variable_set(:@output_type, "any")
        subclass.instance_variable_set(:@output_schema, nil)
      end

      private

      # Recursively symbolizes all hash keys
      # @api private
      def deep_symbolize_keys(hash)
        return hash unless hash.is_a?(Hash)

        hash.transform_keys(&:to_sym).transform_values do |value|
          value.is_a?(Hash) ? deep_symbolize_keys(value) : value
        end
      end
    end

    # Delegate class attribute readers to instances
    def_delegators :"self.class", :tool_name, :description, :inputs, :output_type, :output_schema

    # @!method name
    #   Alias for {#tool_name}
    #   @return [String] The tool name
    alias name tool_name

    # Creates a new tool instance.
    #
    # Validates that all required class attributes (name, description, inputs,
    # output_type) are properly configured. Raises ArgumentError if validation fails.
    #
    # @raise [ArgumentError] if tool_name is not set
    # @raise [ArgumentError] if description is not set
    # @raise [ArgumentError] if inputs is not a Hash
    # @raise [ArgumentError] if output_type is not set or invalid
    # @raise [ArgumentError] if any input specification is invalid
    #
    # @example
    #   tool = MyTool.new  # Validates configuration on instantiation
    def initialize
      @initialized = false
      validate_arguments!
    end

    # Returns whether the tool has been initialized via {#setup}.
    #
    # @return [Boolean] true if setup has been called
    def initialized? = @initialized

    # Invokes the tool with the given arguments.
    #
    # This is the primary method for executing a tool. It:
    # 1. Calls {#setup} if not already initialized
    # 2. Delegates to {#execute} with the provided arguments
    # 3. Wraps the result in a {ToolResult} (unless wrap_result: false)
    #
    # @param args [Array] Positional arguments (single Hash is converted to kwargs)
    # @param sanitize_inputs_outputs [Boolean] Reserved for future input/output sanitization
    # @param wrap_result [Boolean] Whether to wrap result in ToolResult (default: true)
    # @param kwargs [Hash] Keyword arguments matching the tool's inputs specification
    #
    # @return [ToolResult] Wrapped result (if wrap_result is true)
    # @return [Object] Raw result from execute (if wrap_result is false)
    #
    # @example Standard invocation
    #   result = tool.call(query: "ruby gems")
    #   result.data  # => ["gem1", "gem2", ...]
    #
    # @example Getting raw result without wrapping
    #   raw = tool.call(query: "ruby gems", wrap_result: false)
    #   raw  # => ["gem1", "gem2", ...]
    #
    # @example Hash argument style (converted to kwargs)
    #   result = tool.call({ query: "ruby gems" })
    def call(*args, sanitize_inputs_outputs: false, wrap_result: true, **kwargs)
      Instrumentation.instrument("smolagents.tool.call", tool_name: name, tool_class: self.class.name) do
        setup unless @initialized
        kwargs = args.first if args.length == 1 && kwargs.empty? && args.first.is_a?(Hash)
        result = execute(**kwargs)
        wrap_result ? wrap_in_tool_result(result, kwargs) : result
      end
    end

    # Executes the tool's core logic. Subclasses must override this method.
    #
    # This method receives the validated input arguments and should return
    # the tool's result. The return value will be automatically wrapped
    # in a {ToolResult} by {#call}.
    #
    # @abstract
    # @param kwargs [Hash] Keyword arguments matching the inputs specification
    # @return [Object] The tool's output (any type matching output_type)
    # @raise [NotImplementedError] if not overridden in subclass
    #
    # @example Implementing execute
    #   def execute(query:, limit: 10)
    #     search_api.search(query, max_results: limit)
    #   end
    def execute(**_kwargs) = raise(NotImplementedError, "#{self.class}#execute must be implemented")

    # Performs one-time initialization for the tool.
    #
    # Override this method to perform expensive setup operations (database
    # connections, API client initialization, etc.) that should only happen
    # once. Called automatically on first {#call} invocation.
    #
    # Always call `super` at the end of your override to mark the tool
    # as initialized.
    #
    # @return [Boolean] true (marks tool as initialized)
    #
    # @example Lazy database connection
    #   def setup
    #     @db = Database.connect(ENV["DATABASE_URL"])
    #     @cache = Redis.new
    #     super
    #   end
    def setup = @initialized = true

    # Generates a code-style prompt for CodeAgent.
    #
    # Returns a Ruby method signature with documentation that agents
    # can understand and use to generate tool invocation code.
    #
    # @return [String] Ruby-style method documentation
    #
    # @example Output format
    #   def search(query: string, limit: integer) -> array
    #     """
    #     Search for items matching a query
    #
    #     Args:
    #       query: The search query string
    #       limit: Maximum number of results
    #     """
    #   end
    def to_code_prompt
      args_sig = inputs.map { |name, spec| "#{name}: #{spec[:type]}" }.join(", ")
      doc = inputs.any? ? "#{description}\n\nArgs:\n#{inputs.map { |name, spec| "  #{name}: #{spec[:description]}" }.join("\n")}" : description
      doc += "\n\nReturns:\n  Hash (structured output): #{output_schema}" if output_schema
      "def #{name}(#{args_sig}) -> #{output_schema ? "Hash" : output_type}\n  \"\"\"\n  #{doc}\n  \"\"\"\nend\n"
    end

    # Generates a natural language prompt for ToolCallingAgent.
    #
    # Returns a human-readable description of the tool suitable for
    # agents that use JSON-based tool calling.
    #
    # @return [String] Natural language tool description
    def to_tool_calling_prompt = "#{name}: #{description}\n  Takes inputs: #{inputs}\n  Returns an output of type: #{output_type}\n"

    # Converts the tool's metadata to a hash.
    #
    # Useful for serialization, debugging, or building tool registries.
    #
    # @return [Hash{Symbol => Object}] Tool metadata
    # @option return [String] :name The tool name
    # @option return [String] :description The tool description
    # @option return [Hash] :inputs The input specifications
    # @option return [String] :output_type The output type
    # @option return [Hash, nil] :output_schema The output schema (if set)
    def to_h = { name: name, description: description, inputs: inputs, output_type: output_type, output_schema: output_schema }.compact

    # Validates tool configuration, raising on any errors.
    #
    # Called automatically during {#initialize}. Checks that all required
    # class attributes are set and valid.
    #
    # @raise [ArgumentError] if tool_name is not set
    # @raise [ArgumentError] if description is not set
    # @raise [ArgumentError] if inputs is not a Hash
    # @raise [ArgumentError] if output_type is not set
    # @raise [ArgumentError] if output_type is not in {AUTHORIZED_TYPES}
    # @raise [ArgumentError] if any input specification is invalid
    #
    # @return [void]
    def validate_arguments!
      raise ArgumentError, "Tool must have a name" unless name
      raise ArgumentError, "Tool must have a description" unless description
      raise ArgumentError, "Tool inputs must be a Hash" unless inputs.is_a?(Hash)
      raise ArgumentError, "Tool must have an output_type" unless output_type
      raise ArgumentError, "Invalid output_type: #{output_type}" unless AUTHORIZED_TYPES.include?(output_type)

      inputs.each { |input_name, spec| validate_input_spec!(input_name, spec) }
    end

    # Validates tool configuration without raising, returning a boolean.
    #
    # @return [Boolean] true if all configuration is valid
    #
    # @example Checking if a tool is valid
    #   if tool.validate_arguments
    #     puts "Tool is properly configured"
    #   end
    def validate_arguments
      return false unless name && description && inputs.is_a?(Hash) && output_type
      return false unless AUTHORIZED_TYPES.include?(output_type)

      inputs.all? { |_, spec| validate_input_spec(spec) }
    end

    # @!method valid_arguments?
    #   Alias for {#validate_arguments}
    #   @return [Boolean] true if all configuration is valid
    alias valid_arguments? validate_arguments

    # Validates a single input specification, raising on errors.
    #
    # @param input_name [Symbol, String] The input parameter name (for error messages)
    # @param spec [Hash] The input specification to validate
    #
    # @raise [ArgumentError] if spec is not a Hash
    # @raise [ArgumentError] if spec lacks :type key
    # @raise [ArgumentError] if spec lacks :description key
    # @raise [ArgumentError] if type is not in {AUTHORIZED_TYPES}
    #
    # @return [void]
    def validate_input_spec!(input_name, spec)
      raise ArgumentError, "Input '#{input_name}' must be a Hash" unless spec.is_a?(Hash)
      raise ArgumentError, "Input '#{input_name}' must have type" unless spec.key?(:type)
      raise ArgumentError, "Input '#{input_name}' must have description" unless spec.key?(:description)

      Array(spec[:type]).each { |type| raise ArgumentError, "Invalid type '#{type}' for input '#{input_name}'" unless AUTHORIZED_TYPES.include?(type) }
    end

    # Validates a single input specification without raising.
    #
    # @param spec [Hash] The input specification to validate
    # @return [Boolean] true if the specification is valid
    def validate_input_spec(spec)
      spec.is_a?(Hash) && spec.key?(:type) && spec.key?(:description) &&
        Array(spec[:type]).all? { |type| AUTHORIZED_TYPES.include?(type) }
    end

    # @!method valid_input_spec?
    #   Alias for {#validate_input_spec}
    #   @param spec [Hash] The input specification to validate
    #   @return [Boolean] true if the specification is valid
    alias valid_input_spec? validate_input_spec

    # Validates arguments passed to a tool call at runtime.
    #
    # Used by agents to validate tool invocation arguments before calling.
    # Checks for required parameters and rejects unexpected parameters.
    #
    # @param arguments [Hash] The arguments to validate
    #
    # @raise [AgentToolCallError] if arguments is not a Hash
    # @raise [AgentToolCallError] if a required input is missing
    # @raise [AgentToolCallError] if an unexpected input is provided
    #
    # @return [void]
    #
    # @example Validating before invocation
    #   begin
    #     tool.validate_tool_arguments(user_provided_args)
    #     tool.call(**user_provided_args)
    #   rescue AgentToolCallError => e
    #     puts "Invalid arguments: #{e.message}"
    #   end
    def validate_tool_arguments(arguments)
      raise AgentToolCallError, "Tool '#{name}' expects Hash arguments, got #{arguments.class}" unless arguments.is_a?(Hash)

      inputs.each do |input_name, spec|
        next if spec[:nullable]
        raise AgentToolCallError, "Tool '#{name}' missing required input: #{input_name}" unless arguments.key?(input_name) || arguments.key?(input_name.to_sym)
      end
      valid_keys = inputs.keys.flat_map { |key| [key, key.to_sym] }
      arguments.each_key { |key| raise AgentToolCallError, "Tool '#{name}' received unexpected input: #{key}" unless valid_keys.include?(key) }
    end

    private

    # Wraps a tool execution result in a ToolResult object.
    #
    # Handles error detection for string results that look like error messages.
    #
    # @api private
    # @param result [Object] The result from execute
    # @param inputs [Hash] The inputs that were passed to execute
    # @return [ToolResult] Wrapped result
    def wrap_in_tool_result(result, inputs)
      return result if result.is_a?(ToolResult)

      metadata = { inputs: inputs, output_type: output_type }
      if result.is_a?(String) && result.start_with?("Error", "An unexpected error")
        ToolResult.error(StandardError.new(result), tool_name: name, metadata: metadata)
      else
        ToolResult.new(result, tool_name: name, metadata: metadata)
      end
    end
  end
end
