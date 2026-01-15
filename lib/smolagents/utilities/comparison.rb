module Smolagents
  module Utilities
    # Answer comparison and similarity utilities for evaluating agent outputs.
    #
    # Provides methods for extracting entities from text, computing similarity scores,
    # and grouping similar answers. Useful for evaluation harnesses and testing.
    #
    # @example Compare two answers for similarity
    #   similarity = Comparison.similarity(expected_answer, agent_output)
    #   puts "#{(similarity * 100).round}% match"
    #
    # @example Check equivalence with threshold
    #   if Comparison.equivalent?(expected, actual, threshold: 0.8)
    #     puts "Answers match!"
    #   end
    #
    # @example Extract key entities from text
    #   entities = Comparison.extract_entities("Ruby 3.2 was released on Dec 25, 2022")
    #   # => #<Set: {"ruby 3.2", "dec 25, 2022"}>
    #
    # @example Group similar answers for consensus
    #   answers = ["Ruby is great", "Ruby is awesome", "Python is good"]
    #   groups = Comparison.group_similar(answers)
    #   # => [["Ruby is great", "Ruby is awesome"], ["Python is good"]]
    #
    module Comparison
      NUMBERS = /\b\d+(?:,\d{3})*(?:\.\d+)?\b/
      QUOTED_DOUBLE = /"([^"]+)"/
      QUOTED_SINGLE = /'([^']+)'/
      PROPER_NOUNS = /\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b/
      URLS = %r{https?://[^\s<>"]+}
      EMAILS = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/
      TECHNICAL = /\b[a-z]+[-_][a-z]+(?:[-_][a-z]+)*\b/

      class << self
        # Extracts named entities from text for comparison.
        #
        # Scans text for various entity types including numbers, quoted strings,
        # proper nouns, URLs, emails, and technical identifiers. Normalizes all
        # entities to lowercase and returns as a Set.
        #
        # @param text [String, #to_s] Text to extract entities from
        # @return [Set<String>] Unique normalized entities found in text
        #
        # @example Extract entities from a sentence
        #   entities = Comparison.extract_entities("Ruby 3.2 was released on Dec 25, 2022")
        #   # => #<Set: {"ruby 3.2", "dec 25, 2022", "3.2", "25", "2022"}>
        #
        # @example Extract URLs and emails
        #   text = "Contact support@example.com or visit https://example.com"
        #   Comparison.extract_entities(text)
        #   # => #<Set: {"support@example.com", "https://example.com"}>
        ENTITY_PATTERNS = [NUMBERS, QUOTED_DOUBLE, QUOTED_SINGLE, PROPER_NOUNS, URLS, EMAILS, TECHNICAL].freeze

        def extract_entities(text)
          str = text.to_s
          entities = ENTITY_PATTERNS.flat_map { str.scan(it).flatten }
          Set.new(entities.map { it.strip.downcase }.reject(&:empty?))
        end

        # Computes similarity score between two texts using Jaccard index.
        #
        # Extracts entities from both texts and calculates similarity as:
        # intersection_size / union_size. Returns 1.0 if both texts have no entities.
        #
        # @param text_a [String, #to_s] First text to compare
        # @param text_b [String, #to_s] Second text to compare
        # @return [Float] Similarity score between 0.0 (completely different) and 1.0 (identical)
        #
        # @example Compare two answers for similarity
        #   similarity = Comparison.similarity(
        #     "Ruby 3.2 was released on Dec 25, 2022",
        #     "Ruby 3.2 release date: December 25, 2022"
        #   )
        #   # => 0.75 (similar but not identical)
        #
        # @example Identical texts
        #   Comparison.similarity("Same text", "Same text")
        #   # => 1.0
        def similarity(text_a, text_b)
          set_a = extract_entities(text_a)
          set_b = extract_entities(text_b)

          return 1.0 if set_a.empty? && set_b.empty?

          intersection = set_a & set_b
          union = set_a | set_b

          union.empty? ? 0.0 : intersection.size.to_f / union.size
        end

        def equivalent?(text_a, text_b, threshold: 0.7)
          similarity(text_a, text_b) >= threshold
        end

        # Normalizes text for comparison by removing punctuation and standardizing spacing.
        #
        # Converts to lowercase, removes non-word characters, collapses whitespace,
        # and strips leading/trailing spaces.
        #
        # @param text [String, #to_s] Text to normalize
        # @return [String] Normalized text
        #
        # @example Normalize punctuation and spacing
        #   Comparison.normalize("Hello,  World!")
        #   # => "hello world"
        #
        # @example Normalize with special characters
        #   Comparison.normalize("Email: test@example.com (Contact)")
        #   # => "email test example com contact"
        def normalize(text)
          text.to_s
              .downcase
              .gsub(/[^\w\s]/, " ")
              .gsub(/\s+/, " ")
              .strip
        end

        # Extracts the key answer from verbose or multi-sentence text.
        #
        # For short text (< 100 chars), returns as-is. For longer text, attempts
        # to extract the main answer using pattern matching for conclusive phrases
        # ("the answer is", "in conclusion", etc.) or returns the last sentence
        # containing entities.
        #
        # @param text [String, #to_s] Verbose text to extract answer from
        # @return [String] Extracted key answer or original text
        #
        # @example Extract explicit answer
        #   text = "After research, the answer is Python is better than Ruby. This is opinion."
        #   Comparison.extract_key_answer(text)
        #   # => "Python is better than Ruby"
        #
        # @example Extract from conclusion
        #   text = "Analysis shows X. Further evidence shows Y. In conclusion, Z is correct."
        #   Comparison.extract_key_answer(text)
        #   # => "Z is correct"
        #
        # @example Return short text unchanged
        #   Comparison.extract_key_answer("Short answer")
        #   # => "Short answer"
        KEY_ANSWER_PATTERNS = [
          /(?:the answer is|answer:|result:|therefore,?|thus,?|finally,?)\s*(.+?)(?:\.|$)/i,
          /(?:in conclusion,?|to summarize,?)\s*(.+?)(?:\.|$)/i
        ].freeze

        def extract_key_answer(text)
          str = text.to_s.strip
          return str if str.length < 100

          extract_pattern_answer(str) || extract_sentence_answer(str)
        end

        def extract_pattern_answer(str)
          KEY_ANSWER_PATTERNS.each do |pattern|
            match = str.match(pattern)
            return match[1].strip if match
          end
          nil
        end

        def extract_sentence_answer(str)
          sentences = str.split(/[.!?]+/).map(&:strip).compact_blank
          with_entities = sentences.select { |sentence| extract_entities(sentence).any? }
          (with_entities.last || sentences.last || str).strip
        end

        # Groups similar answers together for consensus analysis.
        #
        # Iteratively groups answers based on similarity threshold. Each answer
        # is compared against existing groups; if it matches any member of a group
        # (above threshold), it's added to that group. Otherwise, a new group is
        # created. Returns groups sorted by size (largest first).
        #
        # @param answers [Array<String>] Answers to group
        # @param threshold [Float] Similarity threshold for grouping (default 0.7)
        # @return [Array<Array<String>>] Grouped answers, sorted by group size (descending)
        #
        # @example Group similar agent responses
        #   answers = [
        #     "Ruby is great",
        #     "Ruby is awesome",
        #     "Python is good",
        #     "Python is wonderful"
        #   ]
        #   Comparison.group_similar(answers)
        #   # => [["Ruby is great", "Ruby is awesome"], ["Python is good", "Python is wonderful"]]
        #
        # @example Consensus finding (most common group)
        #   answers = ["Answer A", "Answer A", "Answer B"]
        #   groups = Comparison.group_similar(answers)
        #   consensus = groups.first  # => ["Answer A", "Answer A"]
        def group_similar(answers, threshold: 0.7)
          groups = []

          answers.each do |answer|
            matched_group = groups.find do |group|
              group.any? { |existing| equivalent?(answer, existing, threshold:) }
            end

            if matched_group
              matched_group << answer
            else
              groups << [answer]
            end
          end

          groups.sort_by { |group| -group.size }
        end
      end
    end
  end
end
