module Smolagents
  module Concerns
    module Agents
      module SemanticBreaker
        # Individual semantic failure detectors.
        #
        # Provides detection methods for:
        # - Incoherence: Response doesn't follow logically from context
        # - Goal drift: Agent wandering from original task
        # - Confidence decay: Decreasing certainty in outputs
        # - Semantic loops: Same meaning expressed differently
        module Detectors
          private

          def detect_incoherence(step, context)
            return unless @semantic_config.detector_enabled?(:incoherence)

            score = calculate_incoherence_score(step, context)
            return if score < @semantic_config.incoherence_threshold

            build_detection(:incoherence, score, ["Logical inconsistency detected"])
          end

          def detect_goal_drift(step, context)
            return unless @semantic_config.detector_enabled?(:goal_drift)

            task = context[:task].to_s
            return if task.empty?

            relevance = calculate_task_relevance(step, task)
            drift_score = 1.0 - relevance
            return if drift_score < @semantic_config.drift_threshold

            build_detection(:goal_drift, drift_score, ["Task relevance: #{(relevance * 100).round}%"])
          end

          def detect_confidence_decay(step, context)
            return unless @semantic_config.detector_enabled?(:confidence_decay)

            confidence = extract_confidence(step, context)
            return unless confidence

            @semantic_state[:confidence_history] << confidence
            decay = calculate_confidence_decay
            return if decay < @semantic_config.confidence_decay_threshold

            build_detection(:confidence_decay, decay, ["Confidence declining: #{(decay * 100).round}%"])
          end

          def detect_semantic_loop(step, _context)
            return unless @semantic_config.detector_enabled?(:semantic_loop)

            hash = semantic_hash(step)
            similarity = max_similarity_to_previous(hash)
            @semantic_state[:semantic_hashes] << hash

            return if similarity < @semantic_config.loop_similarity_threshold

            build_detection(:semantic_loop, similarity, ["Semantic similarity: #{(similarity * 100).round}%"])
          end

          def run_enabled_detectors(step, context)
            [
              detect_incoherence(step, context),
              detect_goal_drift(step, context),
              detect_confidence_decay(step, context),
              detect_semantic_loop(step, context)
            ].compact
          end
        end
      end
    end
  end
end
