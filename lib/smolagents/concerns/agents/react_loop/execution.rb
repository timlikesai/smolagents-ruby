module Smolagents
  module Concerns
    module ReActLoop
      # Core loop execution - sync, streaming, and Fiber modes.
      module Execution # rubocop:disable Metrics/ModuleLength
        # @return [RunResult, Enumerator<ActionStep>]
        def run(task, stream: false, reset: true, images: nil, additional_prompting: nil)
          Instrumentation.instrument("smolagents.agent.run", task:, agent_class: self.class.name) do
            prepare_run(reset, images)
            stream ? run_stream(task:, images:, additional_prompting:) : run_sync(task, images:, additional_prompting:)
          end
        end

        def prepare_run(reset, images)
          return unless reset || images

          reset_state if reset
          @task_images = images
        end

        # Fiber-based execution with bidirectional control.
        # @return [Fiber] Yields ActionStep, ControlRequest, or RunResult
        def run_fiber(task, reset: true, images: nil, additional_prompting: nil)
          Fiber.new do
            Instrumentation.instrument("smolagents.agent.run_fiber", task:, agent_class: self.class.name) do
              reset_state if reset
              @task_images = images
              fiber_loop(task:, additional_prompting:, images:)
            end
          end
        end

        def fiber_context? = Thread.current[:smolagents_fiber_context] == true
        def write_memory_to_messages(summary_mode: false) = @memory.to_messages(summary_mode:)

        private

        def consume_fiber(fiber)
          loop do
            case fiber.resume
            in Types::ActionStep then next
            in Types::ControlRequests::Request => req then fiber.resume(handle_sync_control_request(req))
            in Types::RunResult => final then return final
            end
          end
        end

        def handle_sync_control_request(req)
          case req.sync_behavior
          in :default then sync_default_response(req)
          in :approve then Types::ControlRequests::Response.approve(request_id: req.id)
          in :skip then Types::ControlRequests::Response.respond(request_id: req.id, value: nil)
          else raise_sync_error(req)
          end
        end

        def sync_default_response(req)
          value = req.respond_to?(:default_value) ? req.default_value : nil
          value ? Types::ControlRequests::Response.respond(request_id: req.id, value:) : raise_sync_error(req)
        end

        def raise_sync_error(req)
          raise ControlFlowError.new("Control request #{req.class.name} cannot be handled in sync mode",
                                     request_type: req.class.name.split("::").last.to_sym, context: req.to_h)
        end

        def run_sync(task, images:, additional_prompting:)
          consume_fiber(run_fiber(task, reset: false, images:, additional_prompting:))
        end

        def run_stream(task:, images: nil, additional_prompting: nil)
          drain_fiber_to_enumerator(run_fiber(task, reset: false, images:, additional_prompting:))
        end

        def drain_fiber_to_enumerator(fiber)
          Enumerator.new do |y|
            loop do
              case fiber.resume
              in Types::ActionStep => s then y << s
              in Types::ControlRequests::Request => req then fiber.resume(auto_approve(req))
              in RunResult then break
              end
            end
          end
        end

        def auto_approve(req) = Types::ControlRequests::Response.approve(request_id: req.id)

        def after_step(task, step, ctx)
          execute_planning_step_if_needed(task, step, ctx.step_number) { |u| ctx = ctx.add_tokens(u) }
          ctx.advance
        end

        def execute_planning_step_if_needed(_task, _step, _step_number); end

        def fiber_loop(task:, additional_prompting:, images:)
          with_fiber_context { execute_fiber_loop(task, additional_prompting, images) }
        end

        def with_fiber_context
          Thread.current[:smolagents_fiber_context] = true
          yield
        ensure
          Thread.current[:smolagents_fiber_context] = false
        end

        def execute_fiber_loop(task, additional_prompting, images)
          prepare_task(task, additional_prompting:, images:)
          run_steps(task, RunContext.start)
        rescue StandardError => e
          finalize_error(e, @ctx)
        end

        def run_steps(task, ctx)
          @ctx = ctx
          until ctx.exceeded?(@max_steps)
            step, ctx = execute_step_with_monitoring(task, ctx)
            Fiber.yield(step)
            return finalize(:success, step.action_output, ctx) if step.is_final_answer

            ctx = (@ctx = after_step(task, step, ctx))
          end
          finalize(:max_steps_reached, nil, ctx)
        end

        def yield_control(request)
          emit(Events::ControlYielded.create(request_type: request_type_sym(request), request_id: request.id,
                                             prompt: extract_prompt(request)))
          response = Fiber.yield(request)
          emit(Events::ControlResumed.create(request_id: request.id, approved: response.approved?,
                                             value: response.value&.to_s&.slice(0, 100)))
          response
        end

        def request_type_sym(req) = req.class.name.split("::").last.downcase.to_sym

        def extract_prompt(req)
          %i[prompt query description].find { |m| req.respond_to?(m) }&.then { |m| req.send(m) } || req.to_h.to_s
        end
      end
    end
  end
end
