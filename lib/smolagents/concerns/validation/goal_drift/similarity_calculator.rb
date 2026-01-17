module Smolagents
  module Concerns
    module GoalDrift
      # Calculates similarity scores between task and steps.
      #
      # Uses Jaccard similarity with boosting for important term matches
      # to determine how relevant each step is to the original task.
      module SimilarityCalculator
        private

        # Calculates how relevant a step is to the task.
        #
        # @param task [String] Original task
        # @param step [ActionStep] Step to evaluate
        # @return [Float] Relevance score (0.0-1.0)
        def calculate_step_relevance(task, step)
          task_terms = extract_key_terms(task)
          return 1.0 if task_terms.empty?

          step_text = build_step_text(step)
          step_terms = extract_key_terms(step_text)
          return 0.5 if step_terms.empty?

          base_similarity = jaccard_similarity(task_terms, step_terms)
          boost = importance_boost(task, step_text)

          [base_similarity + boost, 1.0].min
        end

        # Jaccard similarity of two term sets.
        #
        # @param set_a [Set<String>] First term set
        # @param set_b [Set<String>] Second term set
        # @return [Float] Similarity score (0.0-1.0)
        def jaccard_similarity(set_a, set_b)
          intersection = (set_a & set_b).size
          union = (set_a | set_b).size
          return 0.5 if union.zero?

          intersection.to_f / union
        end

        # Boost for important term matches.
        #
        # @param task [String] Original task
        # @param step_text [String] Step text
        # @return [Float] Boost value (0.0-0.3)
        def importance_boost(task, step_text)
          important_matches = count_important_matches(task, step_text)
          [important_matches * 0.1, 0.3].min
        end

        # Counts consecutive off-topic steps from the end.
        #
        # @param relevances [Array<Float>] Relevance scores (oldest to newest)
        # @return [Integer] Consecutive off-topic count
        def count_consecutive_off_topic(relevances)
          threshold = @drift_config.similarity_threshold
          count = 0

          relevances.reverse_each do |rel|
            break if rel >= threshold

            count += 1
          end

          count
        end
      end
    end
  end
end
