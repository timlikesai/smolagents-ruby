module Smolagents
  module Utilities
    module Comparison
      # Extracts key answers from verbose text.
      #
      # Uses pattern matching to find conclusive phrases ("the answer is",
      # "in conclusion", etc.) or falls back to the last entity-containing sentence.
      module KeyAnswer
        # Minimum length before extraction is attempted
        MIN_LENGTH = 100

        # Patterns that indicate an answer follows
        PATTERNS = [
          /(?:the answer is|answer:|result:|therefore,?|thus,?|finally,?)\s*(.+?)(?:\.|$)/i,
          /(?:in conclusion,?|to summarize,?)\s*(.+?)(?:\.|$)/i
        ].freeze

        module_function

        # Extracts the key answer from verbose text.
        #
        # @param text [String, #to_s] Text to extract from
        # @return [String] Extracted answer or original text
        #
        # @example
        #   extract("After research, the answer is Paris.") # => "Paris"
        def extract(text)
          str = text.to_s.strip
          return str if str.length < MIN_LENGTH

          from_pattern(str) || from_sentences(str)
        end

        # Attempts to extract answer using known patterns.
        #
        # @param str [String] Text to search
        # @return [String, nil] Matched answer or nil
        def from_pattern(str)
          PATTERNS.each do |pattern|
            match = str.match(pattern)
            return match[1].strip if match
          end
          nil
        end

        # Extracts answer from the last sentence containing entities.
        #
        # @param str [String] Text to search
        # @return [String] Last sentence with entities, or last sentence
        def from_sentences(str)
          sentences = str.split(/[.!?]+/).map(&:strip).compact_blank
          with_entities = sentences.select { EntityExtraction.any?(it) }
          (with_entities.last || sentences.last || str).strip
        end
      end
    end
  end
end
