module Smolagents
  module Errors
    # Structured tool errors with actionable feedback.
    # Research shows agents treat generic errors as "retry signals" instead of
    # parsing them for solutions. ToolError provides structured, actionable feedback.
    #
    # @example Creating a structured tool error
    #   error = Smolagents::Errors::ToolError.new(
    #     code: :invalid_format,
    #     message: "Expression must be a string",
    #     suggestion: "Pass the calculation as a quoted string",
    #     example: 'calculate(expression: "8 * 5")'
    #   )
    #   error.to_observation.include?("invalid_format")  #=> true
    #
    # @example Pattern matching on tool errors
    #   err = Smolagents::Errors::ToolError.new(
    #     code: :bad_input, message: "wrong", suggestion: "fix it", example: nil
    #   )
    #   case err
    #   in Smolagents::Errors::ToolError[code: :bad_input, suggestion:]
    #     "Fix: #{suggestion}"
    #   end  #=> "Fix: fix it"
    ToolError = Data.define(:code, :message, :suggestion, :example) do
      # Formats the error as an actionable observation for the agent.
      def to_observation
        parts = ["Error [#{code}]: #{message}"]
        parts << "Fix: #{suggestion}" if suggestion
        parts << "Example: #{example}" if example
        parts.join("\n")
      end

      # Converts to string for use with raise.
      def to_s = to_observation

      # Creates a ToolError and raises it as a ToolExecutionError.
      def self.raise!(code:, message:, suggestion: nil, example: nil, tool_name: nil)
        error = new(code:, message:, suggestion:, example:)
        raise ToolExecutionError.new(error.to_observation, tool_name:)
      end

      # Predefined error factories for common cases
      class << self
        def invalid_format(expected:, got:, suggestion: nil, example: nil)
          new(code: :invalid_format, message: "Expected #{expected}, got #{got}",
              suggestion: suggestion || "Ensure the argument is of type #{expected}", example:)
        end

        def missing_argument(name:, suggestion: nil, example: nil)
          new(code: :missing_argument, message: "Required argument '#{name}' is missing",
              suggestion: suggestion || "Provide the '#{name}' argument", example:)
        end

        def invalid_value(name:, value:, reason:, suggestion: nil, example: nil)
          new(code: :invalid_value, message: "Invalid value '#{value}' for '#{name}': #{reason}",
              suggestion:, example:)
        end

        def not_found(resource:, identifier:, suggestion: nil)
          new(code: :not_found, message: "#{resource} '#{identifier}' not found",
              suggestion: suggestion || "Check the #{resource.downcase} name or ID", example: nil)
        end

        def rate_limited(retry_after: nil)
          new(code: :rate_limited, message: "Request rate limited#{", retry after #{retry_after}s" if retry_after}",
              suggestion: "Wait before retrying or use a different approach", example: nil)
        end

        def timeout(operation:, duration:)
          new(code: :timeout, message: "#{operation} timed out after #{duration}s",
              suggestion: "Try a simpler request or increase timeout", example: nil)
        end
      end
    end
  end
end
