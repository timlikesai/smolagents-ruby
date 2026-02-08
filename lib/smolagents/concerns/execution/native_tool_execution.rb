module Smolagents
  module Concerns
    # Native tool calling execution for agents.
    #
    # Alternative to {CodeExecution} that uses the model's built-in tool
    # calling API (OpenAI function calling format) instead of generating
    # Ruby code blocks. Best for models that struggle with code generation.
    #
    # == When to Use
    #
    # Set `tool_calling_mode: :native` on the model when:
    # - Model can't reliably generate Ruby code blocks
    # - Model has strong native function calling support
    # - Simpler tool interactions are sufficient (no variable persistence)
    #
    # @see CodeExecution For the code-based execution path
    module NativeToolExecution
      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
        base.include(BudgetTracking)
      end

      # Execute a step using native tool calling.
      #
      # @param action_step [ActionStepBuilder] Step to update with results
      # @return [void]
      def execute_native_step(action_step)
        response = generate_with_tools(action_step)

        if response.tool_calls&.any?
          process_tool_calls(action_step, response.tool_calls)
        else
          action_step.final_answer = response.content
          action_step.observations = response.content
        end
      end

      private

      # Call the model with tools available for native calling.
      def generate_with_tools(action_step)
        response = with_generation_timeout(context: :native_tool) do
          @model.generate(write_memory_to_messages, tools_to_call_from: @tools.values, stop_sequences: nil)
        end
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage
        response
      end

      # Execute each tool call and build observations.
      def process_tool_calls(action_step, tool_calls)
        results = tool_calls.map { |tc| run_tool(tc) }
        action_step.tool_calls = tool_calls

        final = results.find { |r| r[:name] == "final_answer" }
        action_step.final_answer = final[:result] if final
        action_step.observations = format_tool_results(results)
      end

      # Execute a single tool call.
      #
      # @param tc [ToolCall] The tool call to execute
      # @return [Hash] Name and result
      def run_tool(call)
        tool = @tools[call.name] || @tools[call.name.to_s]
        return { name: call.name, result: "Error: unknown tool '#{call.name}'" } unless tool

        args = normalize_tool_args(call.arguments)
        result = tool.call(**args)
        { name: call.name, result: result.to_s }
      rescue StandardError => e
        { name: call.name, result: "Error: #{e.message}" }
      end

      # Normalize argument keys to symbols for tool.call.
      def normalize_tool_args(args)
        return {} unless args.is_a?(Hash)

        args.transform_keys(&:to_sym)
      end

      # Format tool results as observation text.
      def format_tool_results(results)
        results.map { |r| "#{r[:name]}: #{r[:result]}" }.join("\n\n")
      end
    end
  end
end
