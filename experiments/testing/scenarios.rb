# Pre-built test scenarios for common agent patterns.

module Smolagents
  module Testing
    # Pre-built test scenarios for common agent testing patterns.
    #
    # Scenarios provide ready-to-use MockModel configurations for
    # testing common agent behaviors without manual setup.
    #
    # @example Simple answer scenario
    #   model, expected = Scenarios.simple_answer
    #   agent = Smolagents.agent.model { model }.build
    #   result = agent.run("question")
    #   expect(result.output).to eq(expected)
    #
    # @example Multi-step scenario
    #   model = Scenarios.multi_step(steps: 3)
    #   agent = Smolagents.agent.model { model }.tools(:calculate).build
    #   result = agent.run("complex task")
    #   expect(agent.call_log.steps.size).to eq(3)
    #
    # @example Retry success scenario
    #   model = Scenarios.retry_success(failures: 2)
    #   agent = Smolagents.agent
    #     .model { Smolagents.model(:openai).with_retry(max_attempts: 3).build }
    #     .build
    module Scenarios
      extend self

      # Simple single-step scenario that returns an answer.
      #
      # @param answer [String] The answer to return
      # @return [Array(MockModel, String)] Model and expected answer
      #
      # @example
      #   model, expected = Scenarios.simple_answer("42")
      #   result = agent.run("What is 6*7?")
      #   expect(result.output).to eq("42")
      def simple_answer(answer = "42")
        model = MockModel.new
        model.queue_final_answer(answer)
        [model, answer]
      end

      # Multi-step scenario with intermediate tool calls.
      #
      # @param steps [Integer] Number of steps before final answer
      # @param answer [String] The final answer
      # @return [MockModel]
      #
      # @example
      #   model = Scenarios.multi_step(steps: 3)
      #   result = agent.run("complex task")
      #   expect(agent.call_log.steps.size).to eq(3)
      def multi_step(steps: 3, answer: "done")
        model = MockModel.new

        (steps - 1).times do |i|
          model.queue_code_action("step_#{i + 1} = process(#{i + 1})")
        end

        model.queue_final_answer(answer)
        model
      end

      # Tool usage scenario with specific tool calls.
      #
      # @param tool_calls [Array<Hash>] Tool calls to queue
      # @param answer [String] The final answer
      # @return [MockModel]
      #
      # @example
      #   model = Scenarios.with_tool_calls([
      #     { tool: :search, args: "query: 'Ruby'" },
      #     { tool: :fetch, args: "url: 'https://example.com'" }
      #   ])
      def with_tool_calls(tool_calls, answer: "done")
        model = MockModel.new

        tool_calls.each do |tc|
          tool = tc[:tool]
          args = tc[:args] || ""
          model.queue_code_action("#{tool}(#{args})")
        end

        model.queue_final_answer(answer)
        model
      end

      # Retry success scenario - fails N times then succeeds.
      #
      # @param failures [Integer] Number of failures before success
      # @param error [Class] Error class to raise
      # @param answer [String] The final answer after recovery
      # @return [MockModel]
      #
      # @example
      #   model = Scenarios.retry_success(failures: 2)
      #   # First two calls fail, third succeeds
      def retry_success(failures: 2, error: RuntimeError, answer: "recovered")
        model = MockModel.new
        model.fail_then_succeed(failures, with: error, then_respond: wrapped_answer(answer))
        model
      end

      # Evaluation continue scenario - agent checks work and continues.
      #
      # @param steps [Integer] Number of work+evaluation cycles
      # @param answer [String] The final answer
      # @return [MockModel]
      def with_evaluation(steps: 2, answer: "done")
        model = MockModel.new

        steps.times do |i|
          model.queue_step_with_eval(
            "step_#{i + 1} = work()",
            eval_reason: "Step #{i + 1} complete, more work needed"
          )
        end

        model.queue_final_answer(answer)
        model.queue_evaluation_done(answer)
        model
      end

      # Planning scenario - agent plans then executes.
      #
      # @param plan [String] The planning text
      # @param steps [Integer] Number of execution steps
      # @param answer [String] The final answer
      # @return [MockModel]
      def with_planning(plan: "1. Gather info\n2. Process\n3. Return", steps: 2, answer: "done")
        model = MockModel.new
        model.queue_planning_response(plan)

        steps.times do |i|
          model.queue_code_action("execute_step_#{i + 1}()")
        end

        model.queue_final_answer(answer)
        model
      end

      # Stuck agent scenario - agent gets stuck in a loop.
      #
      # @param repetitions [Integer] Number of repeated outputs
      # @return [MockModel]
      #
      # @example Test loop detection
      #   model = Scenarios.stuck_agent(repetitions: 3)
      #   # Agent will repeat the same action 3 times
      def stuck_agent(repetitions: 3)
        model = MockModel.new

        repetitions.times do
          model.queue_code_action("same_action()")
        end

        model.queue_final_answer("finally done")
        model
      end

      # Self-refinement scenario - agent refines its output.
      #
      # @param iterations [Integer] Number of refine iterations
      # @param answer [String] The final refined answer
      # @return [MockModel]
      def with_refinement(iterations: 1, answer: "refined result")
        model = MockModel.new

        model.queue_code_action("initial_answer = 'draft'")
        iterations.times do
          model.queue_critique_issue("Needs improvement", "Add more detail")
          model.queue_refinement("improved_answer = 'better'")
        end
        model.queue_critique_approved
        model.queue_final_answer(answer)
        model
      end

      private

      def wrapped_answer(answer)
        "<code>\nfinal_answer(answer: #{answer.inspect})\n</code>"
      end
    end
  end
end
