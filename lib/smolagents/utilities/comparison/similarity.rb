module Smolagents
  module Utilities
    module Comparison
      # Similarity scoring using Jaccard index on extracted entities.
      #
      # Provides methods for computing similarity scores and equivalence checks
      # between text strings based on their extracted entities.
      module Similarity
        # Default threshold for equivalence checks
        DEFAULT_THRESHOLD = 0.7

        module_function

        # Computes Jaccard similarity between two texts.
        #
        # @param text_a [String, #to_s] First text
        # @param text_b [String, #to_s] Second text
        # @return [Float] Score between 0.0 and 1.0
        #
        # @example
        #   score("Ruby 3.2", "Ruby 3.2 release") # => 0.5
        def score(text_a, text_b)
          set_a = EntityExtraction.extract(text_a)
          set_b = EntityExtraction.extract(text_b)

          return 1.0 if set_a.empty? && set_b.empty?

          jaccard(set_a, set_b)
        end

        # Checks if two texts are equivalent above threshold.
        #
        # @param text_a [String, #to_s] First text
        # @param text_b [String, #to_s] Second text
        # @param threshold [Float] Minimum similarity (default 0.7)
        # @return [Boolean]
        def equivalent?(text_a, text_b, threshold: DEFAULT_THRESHOLD)
          score(text_a, text_b) >= threshold
        end

        # Jaccard index: intersection / union
        #
        # @param set_a [Set] First set
        # @param set_b [Set] Second set
        # @return [Float]
        def jaccard(set_a, set_b)
          union = set_a | set_b
          return 0.0 if union.empty?

          (set_a & set_b).size.to_f / union.size
        end
      end
    end
  end
end
