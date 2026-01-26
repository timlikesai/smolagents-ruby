module Smolagents
  module Utilities
    module PatternMatching
      # Categorizes errors by type using class names and message patterns.
      # Used for retry logic and error handling decisions.
      module ErrorCategorization
        # Pattern-based error detection from message content
        PATTERNS = {
          rate_limit: /rate limit/i,
          timeout: /timeout/i,
          authentication: /unauthorized|invalid.*key/i
        }.freeze

        # Class-based error detection (checked first for precision)
        CLASSES = {
          "Faraday::TooManyRequestsError" => :rate_limit,
          "Faraday::TimeoutError" => :timeout,
          "Faraday::UnauthorizedError" => :authentication
        }.freeze

        class << self
          def categorize(error)
            by_class(error) || by_pattern(error) || :unknown
          end

          private

          def by_class(error)
            CLASSES.find { |name, _| safe_is_a?(error, name) }&.last
          end

          def by_pattern(error)
            PATTERNS.find { |_, pattern| error.message =~ pattern }&.first
          end

          def safe_is_a?(error, class_name)
            error.is_a?(class_name.split("::").reduce(Object) { |m, n| m.const_get(n) })
          rescue NameError
            false
          end
        end
      end
    end
  end
end
