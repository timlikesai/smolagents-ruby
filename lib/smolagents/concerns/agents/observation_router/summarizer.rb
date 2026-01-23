module Smolagents
  module Concerns
    module ObservationRouter
      # Generates semantic summaries of tool output using an LLM.
      # Oneshot call with focused prompt - not a routing decision.
      module Summarizer
        MAX_OUTPUT_FOR_SUMMARY = 3000

        class << self
          # Summarizes tool output for agent reasoning.
          #
          # @param model [Model] LLM to use for summarization
          # @param tool_name [String] Name of the tool that was called
          # @param output [String] The tool output to summarize
          # @param task [String] The current task context
          # @return [String] Formatted summary with relevance and next step
          def summarize(model:, tool_name:, output:, task:)
            prompt = build_prompt(tool_name, output, task)
            response = model.generate([ChatMessage.user(prompt)])
            parse_response(response.content)
          rescue StandardError => e
            "[Summary unavailable: #{e.message}]"
          end

          private

          SUMMARY_PROMPT = <<~PROMPT.freeze
            Summarize this tool output for an AI coding agent. Be concise.

            TASK: %<task>s
            TOOL: %<tool>s
            OUTPUT:
            %<output>s

            Respond in exactly this format (3 lines):
            SUMMARY: [1-2 sentences: what was returned]
            RELEVANCE: [High/Medium/Low] [why in a few words]
            NEXT: [suggested next action for the agent]
          PROMPT

          def build_prompt(tool_name, output, task)
            format(SUMMARY_PROMPT, task:, tool: tool_name, output: truncate_output(output))
          end

          def truncate_output(output)
            str = output.to_s
            if str.length > MAX_OUTPUT_FOR_SUMMARY
              "#{str.slice(0, MAX_OUTPUT_FOR_SUMMARY)}...[truncated, #{str.length} total chars]"
            else
              str
            end
          end

          def parse_response(content)
            lines = []

            lines << "Summary: #{::Regexp.last_match(1).strip}" if content =~ /SUMMARY:\s*(.+?)(?=\nRELEVANCE:|\n*$)/mi

            lines << "Relevance: #{::Regexp.last_match(1).strip}" if content =~ /RELEVANCE:\s*(.+?)(?=\nNEXT:|\n*$)/mi

            lines << "Next: #{::Regexp.last_match(1).strip}" if content =~ /NEXT:\s*(.+?)$/mi

            if lines.empty?
              # Fallback: use raw response if parsing failed
              "Summary: #{content.strip.slice(0, 200)}"
            else
              lines.join("\n")
            end
          end
        end
      end
    end
  end
end
