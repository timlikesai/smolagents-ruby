module Smolagents
  module Tools
    module Support
      # Standardized error-to-string conversion for tools.
      #
      # Provides a consistent way to handle common HTTP errors and convert
      # them to user-friendly error messages rather than raising exceptions.
      #
      # @example Basic usage
      #   include Support::ErrorHandling
      #
      #   def execute(url:)
      #     with_error_handling do
      #       fetch_content(url)
      #     end
      #   end
      #
      # @example With custom error handlers
      #   include Support::ErrorHandling
      #
      #   CUSTOM_ERRORS = {
      #     MyError => "Something specific happened."
      #   }.freeze
      #
      #   def execute(input:)
      #     with_error_handling(CUSTOM_ERRORS) do
      #       process(input)
      #     end
      #   end
      module ErrorHandling
        # Standard error mappings for common Faraday errors.
        STANDARD_ERRORS = {
          Faraday::TimeoutError => "Request timed out.",
          Faraday::ConnectionFailed => "Connection failed."
        }.freeze

        # Executes a block with error handling, returning error strings instead of raising.
        #
        # @param additional_errors [Hash{Class => String, Proc}] Additional error mappings
        # @yield Block to execute with error handling
        # @return [Object, String] Result of block or error message string
        def with_error_handling(additional_errors = {})
          yield
        rescue StandardError => e
          handle_error(e, additional_errors)
        end

        private

        def handle_error(error, additional_errors)
          all_errors = STANDARD_ERRORS.merge(additional_errors)

          handler = find_handler(error, all_errors)
          return apply_handler(handler, error) if handler

          # Default handling for Faraday errors
          return "HTTP error: #{error.message}" if error.is_a?(Faraday::Error)

          # Re-raise unknown errors
          raise error
        end

        def find_handler(error, errors)
          errors.each do |klass, handler|
            return handler if error.is_a?(klass)
          end
          nil
        end

        def apply_handler(handler, error)
          handler.respond_to?(:call) ? handler.call(error) : handler
        end
      end
    end
  end
end
