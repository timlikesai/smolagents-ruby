module Smolagents
  module Concerns
    module Agents
      module SemanticBreaker
        # Analysis utilities for semantic detection.
        #
        # Provides scoring and similarity calculation methods.
        module Analysis
          private

          def calculate_incoherence_score(step, context)
            history = context[:history] || []
            return 0.0 if history.empty?

            current = step_text(step)
            previous = history.last(3).map { |s| step_text(s) }.join(" ")
            1.0 - Utilities::Similarity.string(current, previous)
          end

          def calculate_task_relevance(step, task)
            step_content = step_text(step)
            Utilities::Similarity.string(step_content, task)
          end

          def extract_confidence(step, _context)
            return step.confidence if step.respond_to?(:confidence) && step.confidence

            nil
          end

          def calculate_confidence_decay
            history = @semantic_state[:confidence_history].last(5)
            return 0.0 if history.size < 2

            compute_decay_from_history(history)
          end

          def compute_decay_from_history(history)
            midpoint = history.size / 2
            avg_first = history.take(midpoint).then { |h| h.sum / h.size.to_f }
            avg_second = history.drop(midpoint).then { |h| h.sum / h.size.to_f }
            [(avg_first - avg_second), 0.0].max
          end

          def semantic_hash(step)
            text = step_text(step)
            Utilities::Similarity.trigrams(text)
          end

          def max_similarity_to_previous(current_hash)
            previous = @semantic_state[:semantic_hashes].last(5)
            return 0.0 if previous.empty?

            previous.map { |h| jaccard_similarity(current_hash, h) }.max
          end

          def jaccard_similarity(set_a, set_b)
            return 0.0 if set_a.empty? && set_b.empty?

            intersection = (set_a & set_b).size.to_f
            union = (set_a | set_b).size.to_f
            intersection / union
          end

          def step_text(step)
            parts = []
            parts << step.reasoning if step.respond_to?(:reasoning) && step.reasoning
            parts << step.observations if step.respond_to?(:observations) && step.observations
            parts << step.code_action if step.respond_to?(:code_action) && step.code_action
            parts.join(" ")
          end
        end
      end
    end
  end
end
