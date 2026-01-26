module Smolagents
  module Testing
    module Helpers
      # Builds MockModel instances configured for multi-step agent tests.
      #
      # Handles the complexity of queueing steps with their evaluation
      # responses. Each non-final step automatically gets an evaluation
      # continue response queued after it.
      #
      # @example Step formats
      #   # String: Treated as code action
      #   "search(query: 'Ruby')"
      #
      #   # Hash with :code key: Code action
      #   { code: "search(query: 'Ruby')" }
      #
      #   # Hash with :tool_call key: Tool call
      #   { tool_call: "search", query: "Ruby" }
      #
      #   # Hash with :final_answer key: Final answer (no evaluation)
      #   { final_answer: "Found it!" }
      #
      #   # Hash with :plan key: Planning response (no evaluation)
      #   { plan: "I will search for information" }
      #
      # @see ModelHelpers#mock_model_for_multi_step
      module MultiStepBuilder
        module_function

        # Builds a MockModel with the given steps queued.
        #
        # @param steps [Array<String, Hash>] Steps to queue
        # @return [MockModel] Configured model
        def build(steps)
          MockModel.new.tap { |model| steps.each { |step| queue_step(model, step) } }
        end

        # Queues a single step on the model.
        #
        # @param model [MockModel] The model to configure
        # @param step [String, Hash] The step to queue
        # @return [void]
        def queue_step(model, step)
          case step
          in String => code then queue_code_with_eval(model, code)
          in { code: code_value } then queue_code_with_eval(model, code_value)
          in { tool_call: name, **args } then queue_tool_with_eval(model, name, args)
          in { final_answer: answer } then model.queue_final_answer(answer)
          in { plan: plan } then model.queue_planning_response(plan)
          else queue_generic_with_eval(model, step)
          end
        end

        # @!visibility private
        def queue_code_with_eval(model, code)
          model.queue_code_action(code)
          model.queue_evaluation_continue
        end

        # @!visibility private
        def queue_tool_with_eval(model, name, args)
          model.queue_tool_call(name, **args)
          model.queue_evaluation_continue
        end

        # @!visibility private
        def queue_generic_with_eval(model, step)
          model.queue_response(step.to_s)
          model.queue_evaluation_continue
        end
      end
    end
  end
end
