module Smolagents
  module Utilities
    module Comparison
      # Entity-based similarity scoring.
      #
      # Computes similarity using extracted entities (numbers, names, URLs).
      # Delegates core Jaccard to Utilities::Similarity.
      module Similarity
        DEFAULT_THRESHOLD = 0.7

        module_function

        # Computes entity-based Jaccard similarity between two texts.
        #
        # @param text_a [String, #to_s] First text
        # @param text_b [String, #to_s] Second text
        # @return [Float] Score between 0.0 and 1.0
        def score(text_a, text_b)
          set_a = EntityExtraction.extract(text_a)
          set_b = EntityExtraction.extract(text_b)
          return 1.0 if set_a.empty? && set_b.empty?

          Utilities::Similarity.jaccard(set_a, set_b)
        end

        # Checks if two texts are equivalent above threshold.
        def equivalent?(text_a, text_b, threshold: DEFAULT_THRESHOLD)
          Utilities::Similarity.equivalent?(score(text_a, text_b), threshold:)
        end

        # Delegate to unified module for direct set comparison.
        def jaccard(set_a, set_b) = Utilities::Similarity.jaccard(set_a, set_b)
      end
    end
  end
end
