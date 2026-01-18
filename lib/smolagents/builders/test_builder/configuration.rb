module Smolagents
  module Builders
    # Default configuration and accessors for TestBuilder.
    #
    # Defines the default test configuration hash and provides
    # access methods for the current configuration state.
    module TestBuilderConfiguration
      # Default values for all test configuration options.
      DEFAULT_CONFIG = {
        task: nil,
        validator: nil,
        tools: [],
        max_steps: 5,
        timeout: 60,
        run_count: 1,
        pass_threshold: 1.0,
        metrics: [],
        name: nil,
        capability: :text
      }.freeze

      # Returns a frozen copy of the current configuration.
      #
      # @return [Hash] Frozen configuration hash
      def config
        @config.dup.freeze
      end

      private

      # Initialize configuration with defaults.
      #
      # @return [void]
      def initialize_config
        @config = DEFAULT_CONFIG.dup
      end
    end
  end
end
