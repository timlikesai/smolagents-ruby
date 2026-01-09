# frozen_string_literal: true

module Smolagents
  # JavaScript/TypeScript code validator using pattern matching.
  # Detects dangerous function calls, requires, and global access.
  #
  # @example
  #   validator = JavaScriptValidator.new
  #   validator.validate!("console.log('safe')") # OK
  #   validator.validate!("require('child_process')") # raises InterpreterError
  class JavaScriptValidator < Validator
    protected

    def dangerous_patterns
      [
        # Dangerous builtins
        /\beval\s*\(/,
        /\bFunction\s*\(/,
        /new\s+Function\s*\(/,

        # Dangerous Node.js globals
        /\bprocess\./,
        /\bglobal\./,
        /\b__dirname\b/,
        /\b__filename\b/,

        # Dangerous module patterns
        /require\s*\(\s*['"]child_process/,
        /require\s*\(\s*['"]fs['"]/,
        /require\s*\(\s*['"]net['"]/,
        /require\s*\(\s*['"]http['"]/,
        /require\s*\(\s*['"]https['"]/,
        /require\s*\(\s*['"]vm['"]/,
        /require\s*\(\s*['"]cluster['"]/,
        /require\s*\(\s*['"]worker_threads['"]/,

        # Dynamic requires
        /require\s*\(\s*[^'"]/, # require with variable/expression

        # Import patterns
        /import\s+.*\s+from\s+['"]child_process/,
        /import\s+.*\s+from\s+['"]fs['"]/,
        /import\s+.*\s+from\s+['"]net['"]/,
        /import\s+.*\s+from\s+['"]http['"]/,
        /import\s+.*\s+from\s+['"]vm['"]/,

        # Prototype pollution
        /__proto__/,
        /\.constructor\s*\[/,
        /\.constructor\.prototype/,

        # Dangerous DOM access (if running in browser context)
        /document\./,
        /window\./,
        /XMLHttpRequest/,
        /fetch\s*\(/
      ]
    end

    def dangerous_imports
      %w[
        child_process
        fs
        net
        http
        https
        vm
        cluster
        worker_threads
        os
        path
        stream
        dgram
        dns
      ]
    end

    def check_import(code, import)
      # Check for require()
      code.match?(/require\s*\(\s*['"]#{Regexp.escape(import)}['"]/) ||
        # Check for ES6 import
        code.match?(/import\s+.*\s+from\s+['"]#{Regexp.escape(import)}['"]/)
    end
  end
end
