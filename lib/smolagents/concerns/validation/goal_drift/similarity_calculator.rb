module Smolagents
  module Concerns
    module GoalDrift
      # Calculates similarity scores between task and steps.
      #
      # Uses Jaccard similarity with boosting for important term matches.
      # Delegates core Jaccard to Utilities::Similarity.
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

          base_similarity = Utilities::Similarity.jaccard(task_terms, step_terms)
          boost = importance_boost(task, step_text)

          [base_similarity + boost, 1.0].min
        end

        # Boost for important term matches.
        def importance_boost(task, step_text)
          [count_important_matches(task, step_text) * 0.1, 0.3].min
        end

        # Counts consecutive off-topic steps from the end.
        def count_consecutive_off_topic(relevances)
          threshold = @drift_config.similarity_threshold
          relevances.reverse.take_while { |rel| rel < threshold }.size
        end
      end
    end
  end
end
