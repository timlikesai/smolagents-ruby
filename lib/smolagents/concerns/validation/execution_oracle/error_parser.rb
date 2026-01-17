module Smolagents
  module Concerns
    module ExecutionOracle
      # Parses and categorizes execution errors.
      #
      # Extracts structured information from error messages
      # for each error category (syntax, name, type, etc.).
      module ErrorParser
        # Patterns for extracting information from error messages.
        ERROR_PATTERNS = {
          syntax_error: /syntax error.*?(?:unexpected (\S+)|expecting (\S+))/i,
          name_error: /undefined (?:local variable or method|constant) [`'](\w+)'/i,
          no_method_error: /undefined method [`'](\w+)'(?: for (?:an instance of )?(\S+))?/i,
          type_error: /(?:no implicit conversion of (\S+) into (\S+)|(\S+) can't be coerced into (\S+))/i,
          argument_error: /wrong number of arguments \(given (\d+), expected (\d+(?:\.\.\d+)?)\)/i,
          tool_not_found: /Tool [`'](\w+)' not found/i,
          timeout: /execution timed out|timeout/i,
          memory_limit: /memory limit|out of memory/i,
          operation_limit: /operation limit|too many operations/i
        }.freeze

        # Parses error details based on category.
        # @param category [Symbol] Error category
        # @param message [String] Error message
        # @return [Hash] Parsed details
        def parse_error_details(category, message)
          case category
          in :name_error then parse_name_error(message)
          in :no_method_error then parse_no_method_error(message)
          in :type_error then parse_type_error(message)
          in :argument_error then parse_argument_error(message)
          in :tool_error then parse_tool_error(message)
          in :syntax_error then parse_syntax_error(message)
          else {}
          end
        end

        # Extracts location from error message.
        # @param message [String] Error message
        # @param _code [String, nil] Original code (unused)
        # @return [Hash, nil] Location with line number
        def extract_location(message, _code)
          return nil unless message =~ /:(\d+):/

          { line: ::Regexp.last_match(1).to_i }
        end

        private

        def parse_name_error(message)
          return {} unless message =~ ERROR_PATTERNS[:name_error]

          { undefined_name: ::Regexp.last_match(1) }
        end

        def parse_no_method_error(message)
          return {} unless message =~ ERROR_PATTERNS[:no_method_error]

          {
            undefined_method: ::Regexp.last_match(1),
            receiver_class: ::Regexp.last_match(2)
          }.compact
        end

        def parse_type_error(message)
          return {} unless message =~ ERROR_PATTERNS[:type_error]

          {
            from_type: ::Regexp.last_match(1) || ::Regexp.last_match(3),
            to_type: ::Regexp.last_match(2) || ::Regexp.last_match(4)
          }.compact
        end

        def parse_argument_error(message)
          return {} unless message =~ ERROR_PATTERNS[:argument_error]

          {
            given: ::Regexp.last_match(1).to_i,
            expected: ::Regexp.last_match(2)
          }
        end

        def parse_tool_error(message)
          return {} unless message =~ ERROR_PATTERNS[:tool_not_found]

          { tool_name: ::Regexp.last_match(1) }
        end

        def parse_syntax_error(message)
          details = {}
          details[:unexpected] = ::Regexp.last_match(1) if message =~ /unexpected (\S+)/
          details[:expecting] = ::Regexp.last_match(1) if message =~ /expecting (\S+)/
          details
        end
      end
    end
  end
end
