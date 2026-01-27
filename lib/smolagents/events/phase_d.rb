module Smolagents
  module Events
    # ============================================================
    # Phase D Events: Checkpoints, Semantic Circuit Breaker, MoA
    # ============================================================

    # ---------------------------
    # Checkpoint Events
    # ---------------------------

    define_event :CheckpointCreated,
                 fields: %i[checkpoint_id step_number trigger event_sequence],
                 predicates: { auto: :auto, manual: :manual, recovery: :recovery },
                 predicate_field: :trigger,
                 defaults: { event_sequence: nil }

    define_event :CheckpointRestored,
                 fields: %i[checkpoint_id step_number target_event_sequence elapsed_steps],
                 defaults: { elapsed_steps: nil }

    define_event :CheckpointDeleted,
                 fields: %i[checkpoint_id step_number reason],
                 predicates: { expired: :expired, pruned: :pruned, manual: :manual },
                 predicate_field: :reason

    # ---------------------------
    # Semantic Circuit Breaker Events
    # ---------------------------

    define_event :SemanticFailureDetected,
                 fields: %i[failure_type confidence severity evidence recommended_action],
                 predicates: { incoherence: :incoherence, goal_drift: :goal_drift,
                               confidence_decay: :confidence_decay, semantic_loop: :semantic_loop },
                 predicate_field: :failure_type,
                 freeze: [:evidence]

    define_event :SemanticBreakerTripped,
                 fields: %i[failure_type severity consecutive_failures action_taken],
                 predicates: { paused: :paused, aborted: :aborted },
                 predicate_field: :action_taken

    define_event :SemanticBreakerReset,
                 fields: %i[previous_failure_count recovery_reason],
                 defaults: { recovery_reason: nil }

    # ---------------------------
    # Mixture-of-Agents (MoA) Events
    # ---------------------------

    define_event :ProposerLaunched,
                 fields: %i[proposer_name proposer_index task total_proposers],
                 defaults: { proposer_index: 0 }

    define_event :ProposalReceived,
                 fields: %i[proposer_name confidence duration_ms result_preview],
                 defaults: { result_preview: nil }

    define_event :AggregationCompleted,
                 fields: %i[strategy proposal_count selected_proposer final_confidence duration_ms],
                 predicates: { voting: :voting, synthesis: :synthesis, rank_fusion: :rank_fusion },
                 predicate_field: :strategy,
                 defaults: { selected_proposer: nil, final_confidence: nil }
  end
end
