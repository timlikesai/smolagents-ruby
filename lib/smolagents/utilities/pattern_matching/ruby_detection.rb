module Smolagents
  module Utilities
    module PatternMatching
      # Detects whether extracted text looks like Ruby code.
      # Uses heuristic pattern matching to filter prose from code.
      module RubyDetection
        # Ruby syntax indicators - generous to accept code even if formatting varies
        INDICATORS = [
          /\bdef\s+\w+/,
          /\bend\b/,
          /\bputs\b|\bprint\b/,
          /\w+\s*=\s*\S/,
          /\w+\(.*\)/,
          /\w+\s+\w+:\s/,
          /\bdo\s*\|/,
          /\.each\b|\.map\b/,
          /final_answer/,
          /\bresult\s*=/,
          /\bcalculate\b|\bsearch\b|\bduckduckgo\b/,
          /\breturn\b/,
          /\bclass\s+\w+/,
          /\bmodule\s+\w+/,
          /\brequire\b/,
          /\bnil\b|\btrue\b|\bfalse\b/,
          /\[\]|\{\}/,
          %r{\d+\s*[+\-*/]\s*\d+}
        ].freeze

        class << self
          def looks_like_ruby?(code)
            return false if code.nil? || code.empty? || code.length < 3
            return false if prose_like?(code)

            INDICATORS.any? { it.match?(code) }
          end

          def prose_like?(code)
            code.scan(/[a-z]{4,}/i).length > 10 && code.count("()={}[]") < 3
          end
        end
      end
    end
  end
end
