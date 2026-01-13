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

          Set.new(entities.map { |entity| entity.strip.downcase }.reject(&:empty?))
        end

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

        def normalize(text)
          text.to_s
              .downcase
              .gsub(/[^\w\s]/, " ")
              .gsub(/\s+/, " ")
              .strip
        end

        def extract_key_answer(text)
          str = text.to_s.strip
          return str if str.length < 100

          patterns = [
            /(?:the answer is|answer:|result:|therefore,?|thus,?|finally,?)\s*(.+?)(?:\.|$)/i,
            /(?:in conclusion,?|to summarize,?)\s*(.+?)(?:\.|$)/i
          ]

          patterns.each do |pattern|
            match = str.match(pattern)
            return match[1].strip if match
          end

          sentences = str.split(/[.!?]+/).map(&:strip).reject(&:empty?)
          with_entities = sentences.select { |sentence| extract_entities(sentence).any? }

          (with_entities.last || sentences.last || str).strip
        end

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

          groups.sort_by { |group| -group.size }
        end
      end
    end
  end
end
