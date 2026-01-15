module Smolagents
  module Concerns
    module ReActLoop
      # Core loop execution logic - sync and streaming modes.
      module Execution
        # Execute a task with the agent.
        #
        # @param task [String] The task/question for the agent to solve
        # @param stream [Boolean] If true, return Enumerator of steps
        # @param reset [Boolean] If true, clear memory and state before running
        # @param images [Array<String>, nil] Base64-encoded images
        # @param additional_prompting [String, nil] Extra instructions
        # @return [RunResult] Final result (sync) or [Enumerator<ActionStep>] (stream)
        def run(task, stream: false, reset: true, images: nil, additional_prompting: nil)
          Instrumentation.instrument("smolagents.agent.run", task:, agent_class: self.class.name) do
            reset_state if reset
            @task_images = images
            stream ? run_stream(task:, additional_prompting:, images:) : run_sync(task:, additional_prompting:, images:)
          end
        end

        # Convert agent memory to messages format for the model.
        #
        # @param summary_mode [Boolean] If true, compress history into summaries
        # @return [Array<Hash>] Array of message hashes with :role and :content keys
        def write_memory_to_messages(summary_mode: false) = @memory.to_messages(summary_mode:)

        private

        def run_sync(task:, additional_prompting: nil, images: nil)
          prepare_task(task, additional_prompting:, images:)
          context = RunContext.start

          until context.exceeded?(@max_steps)
            current_step, context = execute_step_with_monitoring(task, context)
            return finalize(:success, current_step.action_output, context) if current_step.is_final_answer

            context = after_step(task, current_step, context)
          end

          finalize(:max_steps_reached, nil, context)
        rescue StandardError => e
          finalize_error(e, context)
        end

        def run_stream(task:, additional_prompting: nil, images: nil)
          Enumerator.new do |yielder|
            prepare_task(task, additional_prompting:, images:)
            step_number = stream_steps(task, yielder)
            emit_task_completed_event(:max_steps_reached, nil, step_number - 1) if step_number > @max_steps
          end
        end

        def stream_steps(task, yielder)
          (1..@max_steps).each do |step_number|
            current_step = process_stream_step(task, step_number)
            yielder << current_step
            return step_number if complete_stream_step?(current_step, step_number)
          end
          @max_steps + 1
        end

        def process_stream_step(task, step_number)
          step(task, step_number:).tap do |s|
            @memory.add_step(s)
            emit_step_completed_event(s)
          end
        end

        def complete_stream_step?(current_step, step_number)
          return false unless current_step.is_final_answer

          emit_task_completed_event(:success, current_step.action_output, step_number)
          true
        end

        def after_step(task, current_step, context)
          execute_planning_step_if_needed(task, current_step, context.step_number) do |usage|
            context = context.add_tokens(usage)
          end
          context.advance
        end

        def execute_planning_step_if_needed(_task, _current_step, _step_number); end
      end
    end
  end
end
