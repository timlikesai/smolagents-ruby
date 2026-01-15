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
            if stream
              run_stream(task:, additional_prompting:,
                         images:)
            else
              consume_fiber(run_fiber(task, reset: false,
                                            images:, additional_prompting:))
            end
          end
        end

        # Execute a task in a Fiber with bidirectional control.
        #
        # Returns a Fiber that yields ActionStep, ControlRequest, or RunResult.
        # Consumer resumes with nil for steps, ControlResponse for requests.
        #
        # @param task [String] The task for the agent
        # @param reset [Boolean] Clear memory before running
        # @param images [Array<String>, nil] Task images
        # @param additional_prompting [String, nil] Extra instructions
        # @return [Fiber] Fiber for interactive execution
        #
        # @example Basic fiber execution
        #   fiber = agent.run_fiber("Find Ruby 4.0 features")
        #   loop do
        #     result = fiber.resume
        #     case result
        #     in Types::ActionStep => step
        #       puts "Step #{step.step_number}"
        #     in Types::RunResult => final
        #       puts final.output
        #       break
        #     end
        #   end
        #
        # @example Handling user input requests
        #   fiber = agent.run_fiber(task)
        #   loop do
        #     result = fiber.resume
        #     case result
        #     in Types::ControlRequests::UserInput => req
        #       response = Types::ControlRequests::Response.respond(request_id: req.id, value: gets.chomp)
        #       fiber.resume(response)
        #     in Types::RunResult => final
        #       break final
        #     end
        #   end
        def run_fiber(task, reset: true, images: nil, additional_prompting: nil)
          Fiber.new do
            Instrumentation.instrument("smolagents.agent.run_fiber", task:, agent_class: self.class.name) do
              reset_state if reset
              @task_images = images
              fiber_loop(task:, additional_prompting:, images:)
            end
          end
        end

        # Check if currently executing in a run_fiber context.
        # Uses thread-local variable set by run_fiber.
        def fiber_context? = Thread.current[:smolagents_fiber_context] == true

        # Convert agent memory to messages format for the model.
        #
        # @param summary_mode [Boolean] If true, compress history into summaries
        # @return [Array<Hash>] Array of message hashes with :role and :content keys
        def write_memory_to_messages(summary_mode: false) = @memory.to_messages(summary_mode:)

        private

        # Consume a fiber synchronously, handling control requests.
        #
        # @param fiber [Fiber] Fiber from run_fiber
        # @return [RunResult] Final result when fiber completes
        def consume_fiber(fiber)
          loop do
            result = fiber.resume
            case result
            in Types::ActionStep then next
            in Types::ControlRequests::Request => request
              fiber.resume(handle_sync_control_request(request))
            in Types::RunResult => final then return final
            end
          end
        end

        # Handle control requests in sync mode based on sync_behavior.
        #
        # @param request [Types::ControlRequests::Request] The control request
        # @return [Types::ControlRequests::Response] Auto-generated response based on behavior
        # @raise [ControlFlowError] When sync_behavior is :raise
        def handle_sync_control_request(request)
          case request.sync_behavior
          in :default
            value = request.respond_to?(:default_value) ? request.default_value : nil
            if value.nil?
              raise_sync_error(request)
            else
              Types::ControlRequests::Response.respond(request_id: request.id,
                                                       value:)
            end
          in :approve
            Types::ControlRequests::Response.approve(request_id: request.id)
          in :skip
            Types::ControlRequests::Response.respond(request_id: request.id, value: nil)
          else
            raise_sync_error(request)
          end
        end

        def raise_sync_error(request)
          raise ControlFlowError.new(
            "Control request #{request.class.name} cannot be handled in sync mode. Use run_fiber for interactive execution.",
            request_type: request.class.name.split("::").last.to_sym,
            context: request.to_h
          )
        end

        # Stream execution wraps Fiber, yielding ActionSteps lazily.
        def run_stream(task:, additional_prompting: nil, images: nil)
          drain_fiber_to_enumerator(run_fiber(task, reset: false, images:, additional_prompting:))
        end

        # Drain a Fiber to an Enumerator, handling control requests.
        #
        # @param fiber [Fiber] Fiber from run_fiber
        # @return [Enumerator<ActionStep>] Lazy enumerator yielding steps
        def drain_fiber_to_enumerator(fiber)
          Enumerator.new do |yielder|
            loop do
              result = fiber.resume
              case result
              in Types::ActionStep => step then yielder << step
              in Types::ControlRequests::Request => req
                fiber.resume(Types::ControlRequests::Response.approve(request_id: req.id))
              in RunResult then break
              end
            end
          end
        end

        def after_step(task, current_step, context)
          execute_planning_step_if_needed(task, current_step, context.step_number) do |usage|
            context = context.add_tokens(usage)
          end
          context.advance
        end

        def execute_planning_step_if_needed(_task, _current_step, _step_number); end

        # Fiber-based execution loop with bidirectional control.
        def fiber_loop(task:, additional_prompting:, images:)
          Thread.current[:smolagents_fiber_context] = true
          prepare_task(task, additional_prompting:, images:)
          context = RunContext.start

          until context.exceeded?(@max_steps)
            current_step, context = execute_step_with_monitoring(task, context)
            Fiber.yield(current_step)
            return finalize(:success, current_step.action_output, context) if current_step.is_final_answer

            context = after_step(task, current_step, context)
          end

          finalize(:max_steps_reached, nil, context)
        rescue StandardError => e
          finalize_error(e, context)
        ensure
          Thread.current[:smolagents_fiber_context] = false
        end

        # Yield control to consumer, requesting input.
        #
        # @param request [Types::ControlRequests::Request] The control request
        # @return [Types::ControlRequests::Response] Consumer's response
        def yield_control(request)
          emit(Events::ControlYielded.create(
                 request_type: request.class.name.split("::").last.downcase.to_sym,
                 request_id: request.id,
                 prompt: extract_prompt_from_request(request)
               ))

          response = Fiber.yield(request)

          emit(Events::ControlResumed.create(
                 request_id: request.id,
                 approved: response.approved?,
                 value: response.value&.to_s&.slice(0, 100)
               ))

          response
        end

        def extract_prompt_from_request(request)
          case request
          when ->(r) { r.respond_to?(:prompt) } then request.prompt
          when ->(r) { r.respond_to?(:query) } then request.query
          when ->(r) { r.respond_to?(:description) } then request.description
          else request.to_h.to_s
          end
        end
      end
    end
  end
end
