# frozen_string_literal: true

module Smolagents
  module Utilities
    # Entity extraction and semantic similarity for answer comparison.
    #
    # These primitives enable ensemble voting, self-consistency checking,
    # and evaluation against expected answers.
    #
    # @example Extract entities from text
    #   Comparison.extract_entities("The answer is 42 and 'hello world'")
    #   #=> #<Set: {"42", "hello world"}>
    #
    # @example Compare two answers
    #   Comparison.similarity("The capital is Paris", "Paris is the capital")
    #   #=> 0.5 (shared entity "Paris")
    #
    module Comparison
      # Patterns for entity extraction
      NUMBERS = /\b\d+(?:,\d{3})*(?:\.\d+)?\b/
      QUOTED_DOUBLE = /"([^"]+)"/
      QUOTED_SINGLE = /'([^']+)'/
      PROPER_NOUNS = /\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b/
      URLS = %r{https?://[^\s<>"]+}
      EMAILS = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/
      TECHNICAL = /\b[a-z]+[-_][a-z]+(?:[-_][a-z]+)*\b/ # kebab-case, snake_case

      class << self
        # Extract comparable entities from text.
        #
        # @param text [String, #to_s] Text to extract entities from
        # @return [Set<String>] Unique entities found
        def extract_entities(text)
          str = text.to_s

          entities = []
          entities.concat(str.scan(NUMBERS))
          entities.concat(str.scan(QUOTED_DOUBLE).flatten)
          entities.concat(str.scan(QUOTED_SINGLE).flatten)
          entities.concat(str.scan(PROPER_NOUNS))
          entities.concat(str.scan(URLS))
          entities.concat(str.scan(EMAILS))
          entities.concat(str.scan(TECHNICAL))

          # Normalize: lowercase, strip whitespace
          Set.new(entities.map { |e| e.strip.downcase }.reject(&:empty?))
        end

        # Calculate Jaccard similarity between two texts based on extracted entities.
        #
        # @param text_a [String, #to_s] First text
        # @param text_b [String, #to_s] Second text
        # @return [Float] Similarity score 0.0-1.0
        def similarity(text_a, text_b)
          set_a = extract_entities(text_a)
          set_b = extract_entities(text_b)

          # Both empty = identical (no entities to compare)
          return 1.0 if set_a.empty? && set_b.empty?

          intersection = set_a & set_b
          union = set_a | set_b

          union.empty? ? 0.0 : intersection.size.to_f / union.size
        end

        # Check if two answers are semantically equivalent.
        #
        # @param text_a [String, #to_s] First answer
        # @param text_b [String, #to_s] Second answer
        # @param threshold [Float] Similarity threshold (default: 0.7)
        # @return [Boolean]
        def equivalent?(text_a, text_b, threshold: 0.7)
          similarity(text_a, text_b) >= threshold
        end

        # Normalize answer text for comparison.
        #
        # @param text [String, #to_s] Text to normalize
        # @return [String] Normalized text
        def normalize(text)
          text.to_s
              .downcase
              .gsub(/[^\w\s]/, " ")  # Remove punctuation
              .gsub(/\s+/, " ")      # Collapse whitespace
              .strip
        end

        # Extract the key answer from verbose output.
        #
        # Tries multiple strategies:
        # 1. Pattern matching ("The answer is X", "Result: X")
        # 2. Last sentence
        # 3. Shortest sentence with entities
        #
        # @param text [String, #to_s] Full output text
        # @return [String] Extracted key answer
        def extract_key_answer(text)
          str = text.to_s.strip
          return str if str.length < 100

          # Try common answer patterns
          patterns = [
            /(?:the answer is|answer:|result:|therefore,?|thus,?|finally,?)\s*(.+?)(?:\.|$)/i,
            /(?:in conclusion,?|to summarize,?)\s*(.+?)(?:\.|$)/i
          ]

          patterns.each do |pattern|
            match = str.match(pattern)
            return match[1].strip if match
          end

          # Fall back to last sentence with entities
          sentences = str.split(/[.!?]+/).map(&:strip).reject(&:empty?)
          with_entities = sentences.select { |s| extract_entities(s).any? }

          (with_entities.last || sentences.last || str).strip
        end

        # Group similar answers together for voting.
        #
        # @param answers [Array<String>] List of answers
        # @param threshold [Float] Similarity threshold for grouping
        # @return [Array<Array<String>>] Groups of similar answers
        def group_similar(answers, threshold: 0.7)
          groups = []

          answers.each do |answer|
            matched_group = groups.find do |group|
              group.any? { |existing| equivalent?(answer, existing, threshold: threshold) }
            end

            if matched_group
              matched_group << answer
            else
              groups << [answer]
            end
          end

          groups.sort_by { |g| -g.size }
        end
      end
    end
  end
end
