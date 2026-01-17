require "forwardable"
require_relative "tool/dsl"
require_relative "tool/validation"
require_relative "tool/error_hints"
require_relative "tool/execution"
require_relative "tool/schema"

module Smolagents
  module Tools
    # Base class for all tools in the smolagents framework.
    #
    # Tools are the building blocks that agents use to interact with the world.
    # Each tool encapsulates a specific capability and exposes it through a
    # standardized interface that agents can discover and invoke.
    #
    # @example Subclassing to create a simple tool
    #   class GreetingTool < Smolagents::Tool
    #     self.tool_name = "greet"
    #     self.description = "Generate a greeting message"
    #     self.inputs = {
    #       name: { type: "string", description: "Name to greet" },
    #       formal: { type: "boolean", description: "Use formal style", nullable: true }
    #     }
    #     self.output_type = "string"
    #
    #     def execute(name:, formal: false)
    #       formal ? "Good day, #{name}." : "Hello, #{name}!"
    #     end
    #   end
    #
    # @example Tool with setup for expensive initialization
    #   class DatabaseTool < Smolagents::Tool
    #     self.tool_name = "query_db"
    #     self.description = "Execute a database query"
    #     self.inputs = { sql: { type: "string", description: "SQL query" } }
    #     self.output_type = "array"
    #
    #     def setup
    #       @connection = Database.connect(ENV["DATABASE_URL"])
    #       super
    #     end
    #
    #     def execute(sql:)
    #       @connection.execute(sql).to_a
    #     end
    #   end
    #
    # @see SearchTool Specialized base class for search tools with DSL
    # @see ToolResult Chainable result wrapper returned by {#call}
    # @see Tools.define_tool DSL for creating tools without subclassing
    class Tool
      extend Forwardable
      extend Dsl
      include Validation
      include Execution
      include Schema

      # Re-export AUTHORIZED_TYPES at class level for compatibility
      AUTHORIZED_TYPES = Dsl::AUTHORIZED_TYPES

      # Delegate class attribute readers to instances
      def_delegators :"self.class", :tool_name, :description, :inputs, :output_type, :output_schema

      # Alias for tool_name
      alias name tool_name

      # Creates a new tool instance.
      #
      # Validates that all required class attributes are properly configured.
      #
      # @raise [ArgumentError] if configuration is invalid
      def initialize
        @initialized = false
        validate_arguments!
      end
    end
  end

  # Re-export Tool at the Smolagents level.
  Tool = Tools::Tool
end
