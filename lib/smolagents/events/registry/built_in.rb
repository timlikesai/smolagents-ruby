# Built-in event registrations for smolagents.
#
# Registers all standard events with their documentation.
# Events are grouped by category: lifecycle, tools, errors,
# subagents, resilience, control, and metacognition.
#
# rubocop:disable Metrics/ModuleLength -- registration file
module Smolagents
  module Events
    module Registry
      # Configuration events
      register :configuration_changed,
               description: "Fired when Smolagents.configure completes",
               params: %i[],
               param_descriptions: {},
               example: "Smolagents.on(:configuration_changed) { reload_settings }",
               category: :lifecycle

      # Lifecycle events
      register :step_complete,
               description: "Fired after each ReAct loop step completes",
               params: %i[step_number outcome observations],
               param_descriptions: {
                 step_number: "Step number that completed",
                 outcome: "Step outcome (:success, :error, :final_answer)",
                 observations: "Observation text from the step"
               },
               example: 'agent.on(:step_complete) { |e| puts "Step #{e.step_number}: #{e.outcome}" }',
               category: :lifecycle

      register :task_complete,
               description: "Fired when the agent completes a task",
               params: %i[outcome output steps_taken],
               param_descriptions: {
                 outcome: "Result status (:success, :error, :max_steps_reached)",
                 output: "Final output value",
                 steps_taken: "Number of steps executed"
               },
               example: "agent.on(:task_complete) { |outcome, out, steps| report(outcome) }",
               category: :lifecycle

      # Tool events
      register :tool_complete,
               description: "Fired after a tool execution completes",
               params: %i[request_id tool_name result observation is_final],
               param_descriptions: {
                 request_id: "Unique ID for tracking the call",
                 tool_name: "Name of the tool that was executed",
                 result: "Result value from execution",
                 observation: "Observation string from result",
                 is_final: "Whether this was a final_answer call"
               },
               example: "agent.on(:tool_complete) { |e| log(e.tool_name, e.result) }",
               category: :tools

      register :tool_call,
               description: "Fired when a tool is about to be called",
               params: %i[tool_name args],
               param_descriptions: {
                 tool_name: "Name of the tool being called",
                 args: "Arguments passed to the tool"
               },
               category: :tools

      # Model events
      register :model_generate_requested,
               description: "Fired when model generation is requested",
               params: %i[model_id message_count has_tools temperature],
               param_descriptions: {
                 model_id: "ID of the model generating",
                 message_count: "Number of messages in context",
                 has_tools: "Whether tools are available",
                 temperature: "Temperature setting"
               },
               example: 'model.on(:model_generate_requested) { |e| log("Generating with #{e.model_id}") }',
               category: :models

      register :model_generate_completed,
               description: "Fired when model generation completes",
               params: %i[model_id duration_ms token_usage has_tool_calls outcome],
               param_descriptions: {
                 model_id: "ID of the model that generated",
                 duration_ms: "Generation time in milliseconds",
                 token_usage: "Token usage statistics",
                 has_tool_calls: "Whether response includes tool calls",
                 outcome: "Result status (:success, :error)"
               },
               example: "model.on(:model_generate_completed) { |e| track_tokens(e.token_usage) }",
               category: :models

      # Error events
      register :error,
               description: "Fired when an error occurs",
               params: %i[error_class error_message context recoverable],
               param_descriptions: {
                 error_class: "Class name of the error",
                 error_message: "Error message string",
                 context: "Additional context hash",
                 recoverable: "Whether the error can be recovered from"
               },
               example: "agent.on(:error) { |cls, msg, ctx, rec| alert(msg) unless rec }",
               category: :errors

      register :rate_limit,
               description: "Fired when a rate limit is hit",
               params: %i[tool_name retry_after original_request],
               param_descriptions: {
                 tool_name: "Tool that hit the limit",
                 retry_after: "Seconds to wait before retry",
                 original_request: "The request that was rate limited"
               },
               category: :errors

      # Sub-agent events
      register :agent_launch,
               description: "Fired when a sub-agent is launched",
               params: %i[agent_name task parent_id],
               param_descriptions: {
                 agent_name: "Name of the launched agent",
                 task: "Task assigned to the agent",
                 parent_id: "ID of the parent agent (if any)"
               },
               category: :subagents

      register :agent_progress,
               description: "Fired when a sub-agent makes progress",
               params: %i[launch_id agent_name step_number message],
               param_descriptions: {
                 launch_id: "ID from the launch event",
                 agent_name: "Name of the agent",
                 step_number: "Current step number",
                 message: "Progress message"
               },
               category: :subagents

      register :agent_complete,
               description: "Fired when a sub-agent completes",
               params: %i[launch_id agent_name outcome output],
               param_descriptions: {
                 launch_id: "ID from the launch event",
                 agent_name: "Name of the agent",
                 outcome: "Result status (:success, :failure, :error)",
                 output: "Agent output value"
               },
               example: "agent.on(:agent_complete) { |id, name, outcome, out| aggregate(out) }",
               category: :subagents

      register :spawn_restricted,
               description: "Fired when a spawn request is denied by policy",
               params: %i[agent_name depth violations spawn_path],
               param_descriptions: {
                 agent_name: "Name of the agent that was denied",
                 depth: "Current spawn depth when denied",
                 violations: "Array of policy violation messages",
                 spawn_path: "Path from root to current agent"
               },
               example: "agent.on(:spawn_restricted) { |name, depth, v, path| log_violation(v) }",
               category: :subagents

      # Resilience events
      register :retry,
               description: "Fired when a retry is requested",
               params: %i[model_id error_class attempt max_attempts],
               param_descriptions: {
                 model_id: "ID of the model being retried",
                 error_class: "Class of the error that triggered retry",
                 attempt: "Current attempt number",
                 max_attempts: "Maximum attempts allowed"
               },
               category: :resilience

      register :failover,
               description: "Fired when failover to a backup model occurs",
               params: %i[from_model_id to_model_id error_class attempt],
               param_descriptions: {
                 from_model_id: "Model that failed",
                 to_model_id: "Backup model being used",
                 error_class: "Error that triggered failover",
                 attempt: "Attempt number"
               },
               category: :resilience

      register :recovery,
               description: "Fired when a model recovers from failures",
               params: %i[model_id attempts_before_recovery],
               param_descriptions: {
                 model_id: "Model that recovered",
                 attempts_before_recovery: "Number of attempts before success"
               },
               category: :resilience

      register :model_changed,
               description: "Fired when the loaded model changes",
               params: %i[from_model_id to_model_id],
               param_descriptions: {
                 from_model_id: "Previous model ID",
                 to_model_id: "New model ID"
               },
               example: 'model.on(:model_changed) { |from, to| log("Switched: #{from} -> #{to}") }',
               category: :resilience

      register :queue_request_started,
               description: "Fired when a queued request starts processing",
               params: %i[model_id queue_depth wait_time],
               param_descriptions: {
                 model_id: "ID of the model processing the request",
                 queue_depth: "Number of requests remaining in queue",
                 wait_time: "Time the request waited in queue (seconds)"
               },
               category: :resilience

      register :queue_request_completed,
               description: "Fired when a queued request completes",
               params: %i[model_id duration success],
               param_descriptions: {
                 model_id: "ID of the model that processed the request",
                 duration: "Time to process the request (seconds)",
                 success: "Whether the request succeeded"
               },
               category: :resilience

      # Dead letter queue events
      register :request_failed,
               description: "Fired when a request fails and is added to the DLQ",
               params: %i[model_id error error_message dlq_size],
               param_descriptions: {
                 model_id: "ID of the model that failed",
                 error: "Error class name",
                 error_message: "Error message",
                 dlq_size: "Current DLQ size after adding failure"
               },
               example: 'model.on(:request_failed) { |id, err, msg, sz| log("Failed: #{msg}") }',
               category: :resilience

      register :request_retried,
               description: "Fired when a failed request is retried from the DLQ",
               params: %i[model_id attempt original_error],
               param_descriptions: {
                 model_id: "ID of the model retrying",
                 attempt: "Attempt number for this request",
                 original_error: "Original error class name"
               },
               example: 'model.on(:request_retried) { |id, att, err| log("Retry #{att}") }',
               category: :resilience

      register :tool_retrying,
               description: "Fired when a tool call is being retried after failure",
               params: %i[attempt max_attempts backoff_seconds error_message],
               param_descriptions: {
                 attempt: "Current attempt number",
                 max_attempts: "Maximum attempts allowed",
                 backoff_seconds: "Seconds to wait before retry",
                 error_message: "Error message from the failed attempt"
               },
               example: 'agent.on(:tool_retrying) { |e| log("Retry #{e.attempt}/#{e.max_attempts}") }',
               category: :resilience

      # Control flow events
      register :control_yielded,
               description: "Fired when the agent yields control for input",
               params: %i[request_type request_id prompt],
               param_descriptions: {
                 request_type: "Type of request (:user_input, :confirmation, :sub_agent_query)",
                 request_id: "Unique ID for correlation",
                 prompt: "Prompt shown to the user"
               },
               example: "agent.on(:control_yielded) { |type, id, prompt| show_modal(prompt) }",
               category: :control

      register :control_resumed,
               description: "Fired when execution resumes after yielding",
               params: %i[request_id approved value],
               param_descriptions: {
                 request_id: "ID from the yield event",
                 approved: "Whether the request was approved",
                 value: "Value provided by the user"
               },
               category: :control

      # Tool isolation events
      # NOTE: Memory limiting is NOT enforced at the Ruby level. For production deployments
      # requiring memory isolation, use external controls (cgroups, ulimit, containers).
      register :tool_isolation_started,
               description: "Fired when isolated tool execution begins",
               params: %i[tool_name timeout_ms],
               param_descriptions: {
                 tool_name: "Name of the tool being executed in isolation",
                 timeout_ms: "Timeout in milliseconds for the execution"
               },
               category: :isolation

      register :tool_isolation_completed,
               description: "Fired when isolated tool execution completes",
               params: %i[tool_name duration_ms success],
               param_descriptions: {
                 tool_name: "Name of the tool that was executed",
                 duration_ms: "Execution duration in milliseconds",
                 success: "Whether execution completed successfully"
               },
               example: "agent.on(:tool_isolation_completed) { |e| log(e.tool_name, e.duration_ms) }",
               category: :isolation

      register :resource_violation,
               description: "Fired when a tool exceeds resource limits",
               params: %i[tool_name violation_type limit_value actual_value],
               param_descriptions: {
                 tool_name: "Name of the tool that violated limits",
                 violation_type: "Type of violation (:timeout, :memory, :cpu)",
                 limit_value: "The configured limit that was exceeded",
                 actual_value: "The actual value that exceeded the limit"
               },
               example: "agent.on(:resource_violation) { |e| alert(e.tool_name, e.violation_type) }",
               category: :isolation

      # Goal tracking events
      register :goal_created,
               description: "Fired when a new goal is created",
               params: %i[goal parent_id],
               param_descriptions: {
                 goal: "The created Goal object",
                 parent_id: "Parent goal ID if subgoal, nil if root"
               },
               example: "agent.on(:goal_created) { |g, _| log(\"Goal: \#{g.description}\") }",
               category: :goals

      register :goal_progress,
               description: "Fired when goal progress is updated",
               params: %i[goal previous_progress],
               param_descriptions: {
                 goal: "The updated Goal object",
                 previous_progress: "Previous progress value"
               },
               example: "agent.on(:goal_progress) { |g, _| log(\"Progress: \#{g.progress}\") }",
               category: :goals

      # NOTE: goal_abandoned was removed - goals can be abandoned via Goal#abandon
      # but there's no corresponding event since the feature is not fully implemented.

      # Orchestration events (EDAA Phase 1)
      register :work_item_queued,
               description: "Fired when a work item is added to the work queue",
               params: %i[work_item_id work_type priority queue_depth],
               param_descriptions: {
                 work_item_id: "UUID of the queued work item",
                 work_type: "Type of work (:model_generate, :tool_call, :code_execution, :sub_agent)",
                 priority: "Priority level (:critical, :high, :normal, :low)",
                 queue_depth: "Queue depth after adding item"
               },
               example: 'orchestrator.on(:work_item_queued) { |e| log("Queued: #{e.work_type}") }',
               category: :orchestration

      register :work_item_dispatched,
               description: "Fired when a work item is dispatched to a worker",
               params: %i[work_item_id work_type wait_time_ms worker_id],
               param_descriptions: {
                 work_item_id: "UUID of the dispatched work item",
                 work_type: "Type of work being dispatched",
                 wait_time_ms: "Time spent waiting in queue (milliseconds)",
                 worker_id: "ID of the worker processing the item"
               },
               category: :orchestration

      register :work_item_completed,
               description: "Fired when a work item completes processing",
               params: %i[work_item_id work_type outcome duration_ms error_class],
               param_descriptions: {
                 work_item_id: "UUID of the completed work item",
                 work_type: "Type of work that completed",
                 outcome: "Result (:success, :error, :timeout, :cancelled)",
                 duration_ms: "Processing time in milliseconds",
                 error_class: "Error class name if failed"
               },
               example: "orchestrator.on(:work_item_completed) { |e| track_metrics(e) }",
               category: :orchestration

      # Phase D: Checkpoint events
      register :checkpoint_created,
               description: "Fired when an execution checkpoint is created",
               params: %i[checkpoint_id step_number trigger event_sequence],
               param_descriptions: {
                 checkpoint_id: "UUID of the created checkpoint",
                 step_number: "Step number when checkpoint was taken",
                 trigger: "What triggered the checkpoint (:auto, :manual, :recovery)",
                 event_sequence: "Event store sequence number at checkpoint"
               },
               example: 'agent.on(:checkpoint_created) { |e| log("Checkpoint at step #{e.step_number}") }',
               category: :checkpoints

      register :checkpoint_restored,
               description: "Fired when execution is restored from a checkpoint",
               params: %i[checkpoint_id step_number target_event_sequence elapsed_steps],
               param_descriptions: {
                 checkpoint_id: "UUID of the restored checkpoint",
                 step_number: "Step number being restored to",
                 target_event_sequence: "Event sequence being rolled back to",
                 elapsed_steps: "Number of steps rolled back"
               },
               category: :checkpoints

      register :checkpoint_deleted,
               description: "Fired when a checkpoint is deleted",
               params: %i[checkpoint_id step_number reason],
               param_descriptions: {
                 checkpoint_id: "UUID of the deleted checkpoint",
                 step_number: "Step number of the deleted checkpoint",
                 reason: "Why deleted (:expired, :pruned, :manual)"
               },
               category: :checkpoints

      # Phase D: Semantic Circuit Breaker events
      register :semantic_failure_detected,
               description: "Fired when semantic analysis detects a potential failure",
               params: %i[failure_type confidence severity evidence recommended_action],
               param_descriptions: {
                 failure_type: "Type of failure (:incoherence, :goal_drift, :confidence_decay, :semantic_loop)",
                 confidence: "Detection confidence (0.0-1.0)",
                 severity: "Severity level (:low, :medium, :high, :critical)",
                 evidence: "Array of supporting observations",
                 recommended_action: "Suggested action (:continue, :warn, :pause, :abort)"
               },
               example: "agent.on(:semantic_failure_detected) { |e| log(e.failure_type) }",
               category: :semantic

      register :semantic_breaker_tripped,
               description: "Fired when semantic circuit breaker trips (threshold exceeded)",
               params: %i[failure_type severity consecutive_failures action_taken],
               param_descriptions: {
                 failure_type: "Type of failure that tripped the breaker",
                 severity: "Final severity level",
                 consecutive_failures: "Number of consecutive semantic failures",
                 action_taken: "Action taken (:paused, :aborted)"
               },
               category: :semantic

      register :semantic_breaker_reset,
               description: "Fired when semantic circuit breaker resets to healthy state",
               params: %i[previous_failure_count recovery_reason],
               param_descriptions: {
                 previous_failure_count: "Number of failures before reset",
                 recovery_reason: "What triggered the reset"
               },
               category: :semantic

      # Phase D: Mixture-of-Agents events
      register :proposer_launched,
               description: "Fired when a MoA proposer agent is launched",
               params: %i[proposer_name proposer_index task total_proposers],
               param_descriptions: {
                 proposer_name: "Name/identifier of the proposer",
                 proposer_index: "Index in the proposer array (0-based)",
                 task: "Task assigned to the proposer",
                 total_proposers: "Total number of proposers in this MoA run"
               },
               example: "moa.on(:proposer_launched) { |e| log(e.proposer_name) }",
               category: :moa

      register :proposal_received,
               description: "Fired when a MoA proposer returns its proposal",
               params: %i[proposer_name confidence duration_ms result_preview],
               param_descriptions: {
                 proposer_name: "Name of the proposer that completed",
                 confidence: "Confidence score of the proposal (0.0-1.0)",
                 duration_ms: "Time taken to generate proposal",
                 result_preview: "First 100 chars of the result"
               },
               category: :moa

      register :aggregation_completed,
               description: "Fired when MoA aggregation phase completes",
               params: %i[strategy proposal_count selected_proposer final_confidence duration_ms],
               param_descriptions: {
                 strategy: "Aggregation strategy used (:voting, :synthesis, :rank_fusion)",
                 proposal_count: "Number of proposals aggregated",
                 selected_proposer: "Name of winning proposer (for voting)",
                 final_confidence: "Confidence of final aggregated result",
                 duration_ms: "Total aggregation time"
               },
               example: "moa.on(:aggregation_completed) { |e| log(e.strategy) }",
               category: :moa
    end
  end
end
# rubocop:enable Metrics/ModuleLength
