module Smolagents
  module Agents
    class ToolCalling
      include Concerns::Monitorable
      include Concerns::ReActLoop
      include Concerns::StepExecution
      include Concerns::Planning
      include Concerns::ManagedAgents
      include Concerns::ToolExecution

      template File.join(__dir__, "../prompts/toolcalling_agent.yaml")

      def initialize(tools:, model:, max_tool_threads: nil, **opts)
        setup_agent(tools: tools, model: model, **opts)
        @max_tool_threads = max_tool_threads || DEFAULT_MAX_TOOL_THREADS
      end

      def step(task, step_number: 0)
        with_step_timing(step_number: step_number) do |action_step|
          execute_tool_calling_step(task, action_step)
        end
      end

      def system_prompt
        render_prompt(:system_prompt)
      end

      private

      def execute_tool_calling_step(_task, action_step)
        @logger.debug("Generating with tools", tool_count: @tools.size)
        response = @model.generate(write_memory_to_messages, tools_to_call_from: @tools.values)
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage

        if response.tool_calls&.any?
          @logger.debug("Executing tool calls", count: response.tool_calls.size)
          tool_outputs = execute_tool_calls(response.tool_calls)
          action_step.tool_calls = response.tool_calls
          action_step.observations = tool_outputs.map(&:observation).join("\n")

          if (final = tool_outputs.find(&:is_final_answer))
            action_step.action_output = final.output
            action_step.is_final_answer = true
          end
        elsif response.content&.length&.positive?
          action_step.observations = response.content
        else
          action_step.error = "Model did not generate tool calls or content"
        end
      end
    end
  end
end
