module Smolagents
  class JavaScriptValidator < Validator
    protected

    def dangerous_patterns
      [
        /\beval\s*\(/,
        /\bFunction\s*\(/,
        /new\s+Function\s*\(/,

        /\bprocess\./,
        /\bglobal\./,
        /\b__dirname\b/,
        /\b__filename\b/,

        /require\s*\(\s*['"]child_process/,
        /require\s*\(\s*['"]fs['"]/,
        /require\s*\(\s*['"]net['"]/,
        /require\s*\(\s*['"]http['"]/,
        /require\s*\(\s*['"]https['"]/,
        /require\s*\(\s*['"]vm['"]/,
        /require\s*\(\s*['"]cluster['"]/,
        /require\s*\(\s*['"]worker_threads['"]/,

        /require\s*\(\s*[^'"]/,

        /import\s+.*\s+from\s+['"]child_process/,
        /import\s+.*\s+from\s+['"]fs['"]/,
        /import\s+.*\s+from\s+['"]net['"]/,
        /import\s+.*\s+from\s+['"]http['"]/,
        /import\s+.*\s+from\s+['"]vm['"]/,

        /__proto__/,
        /\.constructor\s*\[/,
        /\.constructor\.prototype/,

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
      code.match?(/require\s*\(\s*['"]#{Regexp.escape(import)}['"]/) ||
        code.match?(/import\s+.*\s+from\s+['"]#{Regexp.escape(import)}['"]/)
    end
  end
end
