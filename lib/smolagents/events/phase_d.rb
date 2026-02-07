module Smolagents
  module Events
    # Checkpoint events (consolidated: CheckpointCreated + CheckpointRestored + CheckpointDeleted)
    define_event :CheckpointLifecycle,
                 fields: %i[checkpoint_id step_number phase trigger event_sequence
                            target_event_sequence elapsed_steps reason],
                 predicates: { created: :created, restored: :restored, deleted: :deleted },
                 predicate_field: :phase,
                 defaults: { trigger: nil, event_sequence: nil, target_event_sequence: nil,
                             elapsed_steps: nil, reason: nil },
                 category: :checkpoints, description: "Fired during checkpoint lifecycle transitions"

    # Semantic circuit breaker events (consolidated: SemanticFailure + BreakerTripped + BreakerReset)
    define_event :SemanticBreaker,
                 fields: %i[phase failure_type confidence severity evidence recommended_action
                            consecutive_failures action_taken previous_failure_count recovery_reason],
                 predicates: { failure_detected: :failure_detected, tripped: :tripped, reset: :reset },
                 predicate_field: :phase,
                 freeze: [:evidence],
                 defaults: { failure_type: nil, confidence: nil, severity: nil, evidence: nil,
                             recommended_action: nil, consecutive_failures: nil, action_taken: nil,
                             previous_failure_count: nil, recovery_reason: nil },
                 category: :semantic, description: "Fired during semantic breaker lifecycle"

    # Mixture-of-Agents events (consolidated: ProposerLaunched + ProposalReceived + AggregationCompleted)
    define_event :MoaLifecycle,
                 fields: %i[phase proposer_name proposer_index task total_proposers
                            confidence duration_ms result_preview strategy proposal_count
                            selected_proposer final_confidence],
                 predicates: { proposer_launched: :proposer_launched, proposal_received: :proposal_received,
                               aggregation_completed: :aggregation_completed },
                 predicate_field: :phase,
                 defaults: { proposer_name: nil, proposer_index: nil, task: nil, total_proposers: nil,
                             confidence: nil, duration_ms: nil, result_preview: nil, strategy: nil,
                             proposal_count: nil, selected_proposer: nil, final_confidence: nil },
                 category: :moa, description: "Fired during MoA lifecycle transitions"
  end
end
