module Smolagents
  module Concerns
    module ObservationRouter
      # Model-based observation router using an LLM.
      #
      # Uses a fast model (haiku, gemma) to analyze tool output and
      # make routing decisions. Follows the "thinking in Ruby" pattern -
      # the model generates Ruby code that returns a RoutingResult.
      #
      # @see https://arxiv.org/abs/2512.20237 MemR³ routing pattern
      module ModelRouter
        # Creates a model-based router proc.
        #
        # @param model [Model] Fast model for routing decisions
        # @return [Proc] Router callable for use with observation_router=
        def self.create(model)
          lambda do |tool_name, output, task|
            response = model.generate([build_prompt(tool_name, output, task)])
            execute_routing_code(response.content, output)
          end
        end

        # Builds the routing prompt with Ruby code generation.
        def self.build_prompt(tool_name, output, task)
          ChatMessage.user(prompt_template(task, tool_name, truncate_output(output)))
        end

        def self.truncate_output(output, max: 3000)
          str = output.to_s
          str.length > max ? "#{str.slice(0, max)}...[truncated]" : str
        end

        def self.prompt_template(task, tool_name, truncated)
          <<~PROMPT
            Analyze this tool output and return a routing decision as Ruby code.

            TASK: #{task}
            TOOL: #{tool_name}
            OUTPUT:
            #{truncated}

            Write Ruby code that returns a RoutingResult. Think through what the output contains
            and whether it helps accomplish the task.

            ```ruby
            # Your analysis as comments...
            RoutingResult.new(
              decision: :summary_only,  # or :full_output, :needs_retry, :irrelevant
              summary: "What was found in 2-3 sentences",
              relevance: 0.9,  # 0.0-1.0 how relevant to task
              next_action: "Suggested next step",
              full_output: nil
            )
            ```

            Decisions:
            - :summary_only - Found what we need, summary is enough
            - :full_output - Complex data agent should examine in detail
            - :needs_retry - Wrong results, suggest better query/approach
            - :irrelevant - Nothing useful, suggest different tool
          PROMPT
        end

        # Executes the generated Ruby code to get the routing result.
        def self.execute_routing_code(content, original_output)
          code = extract_ruby_code(content)
          result = eval_routing_code(code)
          finalize_result(result, original_output)
        rescue SyntaxError, StandardError => e
          fallback_result(e.message, original_output)
        end

        def self.extract_ruby_code(content)
          match = content.match(/```ruby\s*(.*?)\s*```/m)
          match ? match[1] : content
        end

        def self.eval_routing_code(code)
          # Safe execution context with only RoutingResult available
          SafeContext.new.instance_eval(code)
        end

        # Minimal sandbox for routing code execution.
        class SafeContext
          def RoutingResult = ObservationRouter::RoutingResult # rubocop:disable Naming/MethodName
        end

        def self.finalize_result(result, original_output)
          return fallback_result("Invalid result type", original_output) unless result.is_a?(RoutingResult)

          # Attach full output only if decision requires it
          if result.needs_full_output?
            RoutingResult.new(**result.to_h, full_output: original_output)
          else
            result
          end
        end

        def self.fallback_result(reason, output)
          RoutingResult.new(
            decision: :full_output,
            summary: "Router fallback: #{reason}",
            relevance: 1.0,
            next_action: nil,
            full_output: output
          )
        end
      end
    end
  end
end
