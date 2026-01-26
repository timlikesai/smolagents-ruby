module Smolagents
  module Security
    # Detects dangerous patterns in string arguments.
    module DangerDetector
      SHELL_METACHARACTERS = %w[; | & $ ` \\ < > ( )].freeze
      MAX_ERRORS = 3

      SQL_PATTERNS = [
        /'\s*OR\s+\d+=\d+/i,                    # OR 1=1
        /'\s*OR\s+'[^']+'\s*=\s*'[^']+/i,       # OR 'x'='x
        /UNION\s+SELECT/i,                       # UNION SELECT
        /DROP\s+TABLE/i,                         # DROP TABLE
        /--\s*$/                                 # SQL comment at end
      ].freeze

      PATH_TRAVERSAL_PATTERNS = [
        %r{\.\./},                               # ../
        /\.\.\\/,                                # ..\
        /%2e%2e/i,                               # URL encoded ..
        /%252e%252e/i                            # Double encoded ..
      ].freeze

      class << self
        def detect(value)
          return [] unless value.is_a?(String)

          errors = []
          errors.concat(detect_shell_metacharacters(value))
          errors << sql_error if sql_injection?(value)
          errors << path_error if path_traversal?(value)
          errors.first(MAX_ERRORS)
        end

        def sanitize(value)
          return value unless value.is_a?(String)

          SHELL_METACHARACTERS.reduce(value) { |v, char| v.delete(char) }
        end

        private

        def detect_shell_metacharacters(value)
          SHELL_METACHARACTERS.filter_map do |char|
            "contains dangerous shell metacharacter: #{char}" if value.include?(char)
          end
        end

        def sql_injection?(value)
          SQL_PATTERNS.any? { |pattern| pattern.match?(value) }
        end

        def path_traversal?(value)
          PATH_TRAVERSAL_PATTERNS.any? { |pattern| pattern.match?(value) }
        end

        def sql_error = "contains potential SQL injection pattern"
        def path_error = "contains path traversal attempt"
      end
    end
  end
end
