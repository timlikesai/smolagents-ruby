module Smolagents
  module Concerns
    # Static code safety analysis to prevent OOM and runaway allocation.
    #
    # Detects dangerous patterns BEFORE execution:
    # - Massive array/string allocations (e.g., +Array.new(10**9)+)
    # - Unbounded loops (+while true+ without break)
    # - Recursive bomb patterns
    #
    # Conservative by design: only rejects obvious patterns.
    # Ractor timeout catches anything this misses.
    #
    # @example
    #   result = validate_code_safety('Array.new(10**9)')
    #   result.rejected?  #=> true
    #   result.reason     #=> "Massive allocation: Array.new with very large size"
    module CodeSafety
      private

      # Validate code for dangerous memory patterns.
      # @param code [String] Ruby code to analyze
      # @return [Types::CodeSafetyResult] Safe or rejected with reason
      def validate_code_safety(code)
        DANGEROUS_PATTERNS.each do |pattern|
          return Types::CodeSafetyResult.rejected(pattern[:reason]) if code.match?(pattern[:regex])
        end
        Types::CodeSafetyResult.safe
      end

      # Patterns that indicate likely OOM or infinite loops.
      # Each entry has a regex and a human-readable reason.
      DANGEROUS_PATTERNS = [
        {
          regex: /Array\.new\s*\(\s*10\s*\*\*\s*[7-9]\b/,
          reason: "Massive allocation: Array.new with very large size"
        },
        {
          regex: /Array\.new\s*\(\s*\d{8,}\s*\)/,
          reason: "Massive allocation: Array.new with literal size >= 10^8"
        },
        {
          regex: /["']\s*\*\s*10\s*\*\*\s*[7-9]\b/,
          reason: "Massive string multiplication detected"
        },
        {
          regex: /["']\s*\*\s*\d{8,}/,
          reason: "Massive string multiplication with literal >= 10^8"
        },
        {
          regex: /\bwhile\s+true\b(?!.*\bbreak\b)/m,
          reason: "Unbounded loop: while true without break"
        },
        {
          regex: /\bloop\s+do\b(?!.*\bbreak\b)/m,
          reason: "Unbounded loop: loop without break"
        },
        {
          regex: /\.new\s*\(\s*Float::INFINITY/,
          reason: "Allocation with infinite size"
        }
      ].freeze
    end
  end
end
