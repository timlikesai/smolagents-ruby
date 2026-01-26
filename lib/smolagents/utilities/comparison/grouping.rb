module Smolagents
  module Utilities
    module Comparison
      # Groups similar answers for consensus analysis.
      #
      # Iteratively groups answers based on similarity threshold, useful
      # for finding the most common answer among multiple agent responses.
      module Grouping
        module_function

        # Groups similar answers together.
        #
        # @param answers [Array<String>] Answers to group
        # @param threshold [Float] Similarity threshold (default 0.7)
        # @return [Array<Array<String>>] Groups sorted by size (descending)
        #
        # @example
        #   group(["Ruby is great", "Ruby is awesome", "Python"])
        #   # => [["Ruby is great", "Ruby is awesome"], ["Python"]]
        def group(answers, threshold: Similarity::DEFAULT_THRESHOLD)
          groups = build_groups(answers, threshold)
          sort_by_size(groups)
        end

        # Builds groups by matching answers to existing groups.
        #
        # @param answers [Array<String>] Answers to group
        # @param threshold [Float] Similarity threshold
        # @return [Array<Array<String>>] Unsorted groups
        def build_groups(answers, threshold)
          answers.each_with_object([]) do |answer, groups|
            matched = find_matching_group(groups, answer, threshold)
            matched ? matched << answer : groups << [answer]
          end
        end

        # Finds a group containing a similar answer.
        #
        # @param groups [Array<Array<String>>] Existing groups
        # @param answer [String] Answer to match
        # @param threshold [Float] Similarity threshold
        # @return [Array<String>, nil] Matching group or nil
        def find_matching_group(groups, answer, threshold)
          groups.find { |g| g.any? { Similarity.equivalent?(answer, it, threshold:) } }
        end

        # Sorts groups by size, largest first.
        #
        # @param groups [Array<Array<String>>] Groups to sort
        # @return [Array<Array<String>>] Sorted groups
        def sort_by_size(groups) = groups.sort_by { -it.size }
      end
    end
  end
end
