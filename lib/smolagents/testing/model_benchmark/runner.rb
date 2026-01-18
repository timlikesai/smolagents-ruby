module Smolagents
  module Testing
    class ModelBenchmark
      # Test execution logic for model benchmarks.
      # Supports chat, agent, and vision test types.
      module Runner
        TEST_RUNNERS = { chat: :run_chat_test, agent: :run_agent_test, vision: :run_vision_test }.freeze

        # @param model_id [String] Model to test
        # @param test [Hash] Test definition
        # @param timeout [Integer] Timeout in seconds
        # @return [BenchmarkResult]
        def run_test(model_id, test, timeout:)
          method_name = TEST_RUNNERS.fetch(test[:type])
          send(method_name, model_id, test, timeout:)
        rescue StandardError => e
          build_failure(model_id, test, e)
        end

        private

        def run_chat_test(model_id, test, timeout:)
          model = build_model(model_id, timeout:)
          timed_run(model_id, test) do
            response = model.generate([Types::ChatMessage.user(test[:prompt])])
            { passed: test[:validator].call(response.content), tokens: response.token_usage,
              error: "Validation failed" }
          end
        end

        def run_agent_test(model_id, test, timeout:)
          model = build_model(model_id, timeout:)
          agent = Agents::Agent.new(model:, tools: build_tools(test[:tools]), max_steps: test[:max_steps])
          timed_run(model_id, test) do
            result = agent.run(test[:task])
            error = result.max_steps? ? "Max steps reached" : "Validation failed"
            { passed: test[:validator].call(result), tokens: result.token_usage, steps: result.step_count, error: }
          end
        end

        def run_vision_test(model_id, test, timeout:)
          model = build_model(model_id, timeout:)
          message = Types::ChatMessage.user(test[:prompt], images: [test[:image_url]])
          timed_run(model_id, test) do
            response = model.generate([message])
            { passed: test[:validator].call(response.content), tokens: response.token_usage,
              error: "Validation failed" }
          end
        end

        def timed_run(model_id, test)
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          outcome = yield
          duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
          build_test_result(model_id, test, duration, outcome)
        end

        def build_test_result(model_id, test, duration, outcome)
          common = { model_id:, test_name: test[:name], level: test[:level], duration:, tokens: outcome[:tokens],
                     steps: outcome[:steps] }
          return BenchmarkResult.success(**common) if outcome[:passed]

          BenchmarkResult.failure(**common, error: outcome[:error])
        end

        def build_failure(model_id, test, error)
          BenchmarkResult.failure(model_id:, test_name: test[:name], level: test[:level], duration: 0,
                                  error: "#{error.class}: #{error.message}")
        end

        def build_model(model_id, timeout:)
          Models::OpenAIModel.new(model_id:, api_base: @base_url, api_key: "not-needed", timeout:)
        end
      end
    end
  end
end
