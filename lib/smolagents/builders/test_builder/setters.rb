module Smolagents
  module Builders
    # Setter methods for TestBuilder.
    #
    # Provides chainable configuration methods for test parameters.
    # Each method returns a new builder instance for immutable chaining.
    #
    # @see TestBuilder The main builder class
    module TestBuilderSetters
      # Set the test task prompt.
      # @param prompt [String] The task prompt
      # @return [TestBuilder] New builder with updated configuration
      def task(prompt)
        check_frozen!
        with_config(task: prompt)
      end

      # Set the maximum number of agent steps.
      # @param steps [Integer] Maximum steps
      # @return [TestBuilder] New builder with updated configuration
      def max_steps(steps)
        check_frozen!
        with_config(max_steps: steps)
      end

      # Set the execution timeout in seconds.
      # @param seconds [Integer] Timeout in seconds
      # @return [TestBuilder] New builder with updated configuration
      def timeout(seconds)
        check_frozen!
        with_config(timeout: seconds)
      end

      # Set the number of test runs for reliability testing.
      # @param count [Integer] Number of runs
      # @return [TestBuilder] New builder with updated configuration
      def run_n_times(count)
        check_frozen!
        with_config(run_count: count)
      end

      # Set the required pass rate threshold.
      # @param threshold [Float] Pass threshold (0.0-1.0)
      # @return [TestBuilder] New builder with updated configuration
      def pass_threshold(threshold)
        check_frozen!
        with_config(pass_threshold: threshold)
      end

      # Set the test name identifier.
      # @param test_name [String] Test name
      # @return [TestBuilder] New builder with updated configuration
      def name(test_name)
        check_frozen!
        with_config(name: test_name)
      end

      # Set the tested capability.
      # @param cap [Symbol] Capability (:text, :code, :tool_use)
      # @return [TestBuilder] New builder with updated configuration
      def capability(cap)
        check_frozen!
        with_config(capability: cap)
      end

      # Set tools available to the agent.
      # @param tool_list [Array] Tools to make available
      # @return [TestBuilder] New builder with updated configuration
      def tools(*tool_list)
        check_frozen!
        with_config(tools: tool_list.flatten)
      end

      # Set metrics to collect during test.
      # @param metric_list [Array] Metrics to collect
      # @return [TestBuilder] New builder with updated configuration
      def metrics(*metric_list)
        check_frozen!
        with_config(metrics: metric_list.flatten)
      end

      # Sets a validation block for the test result.
      #
      # @yield [result] Block that receives the agent's output
      # @yieldparam result [String] The agent's final answer
      # @yieldreturn [Boolean] Whether the result passes validation
      # @return [TestBuilder] New builder with updated configuration
      def expects(&block)
        check_frozen!
        with_config(validator: block)
      end

      # Sets a validator object/proc for the test result.
      #
      # @param validator [#call] Any callable that validates the result
      # @return [TestBuilder] New builder with updated configuration
      def expects_validator(validator)
        check_frozen!
        with_config(validator:)
      end
    end
  end
end
