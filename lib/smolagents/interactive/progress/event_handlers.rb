module Smolagents
  module Interactive
    module Progress
      # Event handlers for progress display.
      #
      # Processes instrumentation events and updates progress components.
      # Extracted from Progress module to maintain line limits.
      #
      module EventHandlers
        private

        def handle_agent_run(payload)
          case payload[:outcome]
          when nil then reset_for_new_run
          when :success, :final_answer then finish_run
          when :error then @spinner.fail("Error: #{payload[:error_message] || payload[:error]}")
          end
        end

        def handle_agent_step(payload)
          step = payload[:step_number]
          outcome = payload[:outcome]

          return step_starting(step) unless outcome

          @step_tracker.complete_step(step, outcome)
        end

        def handle_model_generate(payload)
          case payload[:outcome]
          when nil then @spinner.start("Generating response...")
          when :success, :final_answer then finish_generate(payload)
          when :error then @spinner.fail("Model error")
          end
        end

        def handle_tool_call(payload)
          tool_name = payload[:tool_name] || payload[:tool_class]

          case payload[:outcome]
          when nil then @step_tracker.update_description("Calling #{tool_name}...")
          when :success then show_tool_result(tool_name)
          when :error then show_tool_error(tool_name, payload[:error_message])
          end
        end

        def reset_for_new_run
          @step_tracker.reset
          @token_counter.reset
        end

        def finish_run
          @spinner.stop
          @token_counter.display
        end

        def step_starting(step)
          @spinner.stop
          @step_tracker.start_step(step, "Thinking...")
        end

        def finish_generate(payload)
          @spinner.stop
          track_tokens(payload)
        end

        def track_tokens(payload)
          input = payload[:input_tokens] || payload.dig(:usage, :input_tokens) || 0
          output = payload[:output_tokens] || payload.dig(:usage, :output_tokens) || 0
          @token_counter.add(input:, output:)
        end
      end
    end
  end
end
