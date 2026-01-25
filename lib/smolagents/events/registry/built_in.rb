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

      # Metacognition events
      register :evaluation_complete,
               description: "Fired when evaluation phase completes",
               params: %i[step_number status answer reasoning confidence],
               param_descriptions: {
                 step_number: "Step being evaluated",
                 status: "Evaluation status (:goal_achieved, :continue, :stuck)",
                 answer: "Answer if goal achieved",
                 reasoning: "Evaluation reasoning",
                 confidence: "Confidence score (0.0-1.0)"
               },
               category: :metacognition

      register :refinement_complete,
               description: "Fired when self-refinement completes",
               params: %i[iterations improved confidence],
               param_descriptions: {
                 iterations: "Number of refinement iterations",
                 improved: "Whether output was improved",
                 confidence: "Final confidence score"
               },
               category: :metacognition

      register :goal_drift,
               description: "Fired when goal drift is detected",
               params: %i[level task_relevance off_topic_count],
               param_descriptions: {
                 level: "Drift severity (:mild, :moderate, :severe)",
                 task_relevance: "Relevance score to original task",
                 off_topic_count: "Number of off-topic steps"
               },
               category: :metacognition

      register :repetition_detected,
               description: "Fired when repetitive behavior is detected",
               params: %i[pattern count guidance],
               param_descriptions: {
                 pattern: "Type of repetition (:tool_call, :code_action, :observation)",
                 count: "Number of repetitions detected",
                 guidance: "Suggested action to break the loop"
               },
               category: :metacognition

      register :reflection_recorded,
               description: "Fired when a reflection is recorded",
               params: %i[outcome reflection],
               param_descriptions: {
                 outcome: "What triggered reflection (:failure, :success)",
                 reflection: "The recorded reflection text"
               },
               category: :metacognition

      register :plan_divergence,
               description: "Fired when agent actions diverge from the generated plan",
               params: %i[level task_relevance off_topic_count],
               param_descriptions: {
                 level: "Divergence severity (:mild, :moderate, :severe)",
                 task_relevance: "Alignment score to current plan (0.0-1.0)",
                 off_topic_count: "Number of consecutive off-plan steps"
               },
               example: "agent.on(:plan_divergence) { |e| log(\"Plan drift: \#{e.level}\") }",
               category: :metacognition

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

      register :goal_completed,
               description: "Fired when a goal is completed",
               params: %i[goal evidence],
               param_descriptions: {
                 goal: "The completed Goal object",
                 evidence: "Evidence of completion"
               },
               example: "agent.on(:goal_completed) { |g, e| log(\"Done: \#{e}\") }",
               category: :goals

      register :goal_abandoned,
               description: "Fired when a goal is abandoned",
               params: %i[goal reason],
               param_descriptions: {
                 goal: "The abandoned Goal object",
                 reason: "Reason for abandonment"
               },
               example: "agent.on(:goal_abandoned) { |g, r| log(\"Abandoned: \#{r}\") }",
               category: :goals
    end
  end
end
# rubocop:enable Metrics/ModuleLength
