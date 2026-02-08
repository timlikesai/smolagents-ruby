module Smolagents
  module Testing
    # Pre-configured MockModel factories for local GPU testing scenarios.
    #
    # Each factory returns a MockModel pre-loaded with responses that simulate
    # common local GPU model behaviors. Use these to test agent resilience
    # against realistic local model constraints.
    #
    # @example Testing against an unreliable model
    #   model = GpuFixtures.unreliable_model(
    #     failure_rate: 0.5,
    #     responses: ['search(query: "test")', 'final_answer(answer: "done")']
    #   )
    #   agent = Smolagents.agent.model { model }.tools(:search).build
    #   result = agent.run("test")
    #
    # @see MockModel For the underlying mock implementation
    module GpuFixtures
      class << self
        # Model that fails intermittently (simulates CUDA OOM, connection drops).
        #
        # Interleaves failures between queued responses. Useful for testing
        # retry and circuit breaker behavior.
        #
        # @param failure_rate [Float] Fraction of calls that fail (0.0-1.0)
        # @param responses [Array<String>] Code responses to queue
        # @param error_class [Class] Error class for failures (default RuntimeError)
        # @return [MockModel]
        def unreliable_model(failure_rate: 0.3, responses: [], error_class: RuntimeError)
          model = MockModel.new(model_id: "fixture-unreliable")
          responses.each do |response|
            model.queue_failure(error_class, "Simulated GPU failure") if rand < failure_rate
            model.queue_code_action(response)
          end
          model
        end

        # Model that fails N times then succeeds (simulates startup/warmup).
        #
        # @param warmup_failures [Integer] Number of initial failures
        # @param responses [Array<String>] Code responses after warmup
        # @param error_class [Class] Error class for warmup failures
        # @return [MockModel]
        def slow_startup_model(warmup_failures: 2, responses: [], error_class: RuntimeError)
          model = MockModel.new(model_id: "fixture-slow-startup")
          model.fail_next(warmup_failures, with: error_class, message: "Model loading...")
          responses.each { |r| model.queue_code_action(r) }
          model
        end

        # Model that returns responses without tool-calling support.
        #
        # Forces code-based tool usage by returning plain code actions.
        # Useful for testing agents with models that lack native tool calling.
        #
        # @param responses [Array<String>] Code responses to queue
        # @return [MockModel]
        def no_tool_calling_model(responses: [])
          model = MockModel.new(model_id: "fixture-no-tools")
          responses.each { |r| model.queue_code_action(r) }
          model
        end

        # Model that returns truncated/degraded responses.
        #
        # Simulates limited context window by providing shorter responses.
        # Useful for testing graceful degradation.
        #
        # @param responses [Array<String>] Code responses to queue
        # @return [MockModel]
        def limited_context_model(responses: [])
          model = MockModel.new(model_id: "fixture-limited-context")
          responses.each do |r|
            model.queue_response(r, input_tokens: 10, output_tokens: 5)
          end
          model
        end

        # Composite local GPU model combining common failure patterns.
        #
        # Simulates: 1 warmup failure, then queued responses.
        # Useful as a default "realistic local model" for integration tests.
        #
        # @param responses [Array<String>] Code responses after warmup
        # @return [MockModel]
        def local_gpu_model(responses: [])
          slow_startup_model(warmup_failures: 1, responses:)
        end
      end
    end
  end
end
