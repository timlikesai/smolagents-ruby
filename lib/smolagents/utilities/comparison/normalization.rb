module Smolagents
  module Utilities
    module Comparison
      # Text normalization utilities for comparison.
      #
      # Provides methods for standardizing text before comparison by
      # removing punctuation, collapsing whitespace, and lowercasing.
      module Normalization
        module_function

        # Normalizes text for comparison.
        #
        # @param text [String, #to_s] Text to normalize
        # @return [String] Normalized text
        #
        # @example
        #   normalize("Hello, World!") # => "hello world"
        def normalize(text)
          text.to_s
              .downcase
              .gsub(/[^\w\s]/, " ")
              .gsub(/\s+/, " ")
              .strip
        end
      end
    end
  end
end
