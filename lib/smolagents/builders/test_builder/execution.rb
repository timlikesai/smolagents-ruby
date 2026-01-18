module Smolagents
  module Builders
    # Test execution methods for TestBuilder.
    #
    # Provides methods to run tests against models, including
    # support for mock models configured via blocks.
    module TestBuilderExecution
      # Runs the test against a model.
      #
      # @param model [Models::Model] The model to test
      # @return [Testing::TestRun] Aggregated results from all runs
      def run(model)
        test_case = build_test_case
        runner = Testing::TestRunner.new(test_case, model)
        runner.run(times: @config[:run_count], threshold: @config[:pass_threshold])
      end

      # Runs the test with a MockModel configured via block.
      #
      # @yield [mock] Block to configure the mock model
      # @yieldparam mock [Testing::MockModel] The mock model to configure
      # @return [Testing::TestRun] Test results
      def with_mock
        mock = Testing::MockModel.new
        yield(mock)
        run(mock)
      end
    end
  end
end
