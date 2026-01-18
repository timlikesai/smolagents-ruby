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
      # Lifecycle events
      register :step_complete,
               description: "Fired after each ReAct loop step completes",
               params: %i[step context],
               param_descriptions: {
                 step: "ActionStep or PlanningStep that completed",
                 context: "RunContext with current state"
               },
               example: 'agent.on(:step_complete) { |step, ctx| puts "Step #{ctx.step_number}" }',
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
               params: %i[tool_call result],
               param_descriptions: {
                 tool_call: "ToolCall that was executed",
                 result: "ToolResult from execution"
               },
               example: "agent.on(:tool_complete) { |call, result| log(call.name, result) }",
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
    end
  end
end
# rubocop:enable Metrics/ModuleLength
