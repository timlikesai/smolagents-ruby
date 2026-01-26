module Smolagents
  module Utilities
    module Comparison
      # Extracts named entities from text for comparison.
      #
      # Supports multiple entity types: numbers, quoted strings, proper nouns,
      # URLs, emails, and technical identifiers (kebab/snake case).
      module EntityExtraction
        # Pattern definitions for entity types
        PATTERNS = {
          numbers: /\b\d+(?:,\d{3})*(?:\.\d+)?\b/,
          quoted_double: /"([^"]+)"/,
          quoted_single: /'([^']+)'/,
          proper_nouns: /\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b/,
          urls: %r{https?://[^\s<>"]+},
          emails: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/,
          technical: /\b[a-z]+[-_][a-z]+(?:[-_][a-z]+)*\b/
        }.freeze

        ALL_PATTERNS = PATTERNS.values.freeze

        module_function

        # Extracts named entities from text.
        #
        # @param text [String, #to_s] Text to extract entities from
        # @return [Set<String>] Unique normalized entities found
        #
        # @example
        #   extract("Ruby 3.2 was released") # => #<Set: {"ruby 3.2", "3.2"}>
        def extract(text)
          str = text.to_s
          entities = ALL_PATTERNS.flat_map { str.scan(it).flatten }
          Set.new(entities.map { it.strip.downcase }.reject(&:empty?))
        end

        # Check if text contains any extractable entities.
        #
        # @param text [String, #to_s] Text to check
        # @return [Boolean]
        def any?(text) = extract(text).any?
      end
    end
  end
end
