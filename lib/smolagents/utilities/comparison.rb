module Smolagents
  module Utilities
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

          Set.new(entities.map { |e| e.strip.downcase }.reject(&:empty?))
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
          with_entities = sentences.select { |s| extract_entities(s).any? }

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

          groups.sort_by { |g| -g.size }
        end
      end
    end
  end
end
