# Global test mode configuration for deterministic agent testing.

module Smolagents
  module Testing
    # Global test mode configuration.
    #
    # Enables a testing context that configures sensible defaults for
    # deterministic testing: no network calls, verbose logging, and
    # predictable behavior.
    #
    # @example Enable test mode globally
    #   Smolagents.test_mode!
    #   agent = Smolagents.agent.model { mock }.build
    #   # Test mode is active for this agent
    #
    # @example Scoped test mode
    #   Smolagents.test_mode do
    #     agent = Smolagents.agent.model { mock }.build
    #     agent.run("task")
    #   end
    #   # Test mode automatically disabled after block
    #
    # @example Check test mode status
    #   Smolagents.test_mode? # => true or false
    #
    # @see MockModel For deterministic model responses
    # @see Helpers For test setup conveniences
    module TestMode
      extend self

      # Thread-local storage for test mode state.
      # @return [Boolean]
      def test_mode? = Thread.current[:smolagents_test_mode] == true

      # Enables test mode globally.
      #
      # Configures sensible defaults for testing:
      # - Disables automatic network requests
      # - Enables verbose event emission
      # - Sets deterministic random seeds where applicable
      #
      # @return [self]
      def enable!
        Thread.current[:smolagents_test_mode] = true
        apply_test_defaults
        self
      end

      # Disables test mode.
      #
      # @return [self]
      def disable!
        Thread.current[:smolagents_test_mode] = false
        self
      end

      # Executes a block in test mode.
      #
      # Test mode is automatically disabled after the block completes,
      # even if an exception is raised.
      #
      # @yield Block to execute in test mode
      # @return [Object] Result of the block
      def scope
        was_enabled = test_mode?
        enable!
        yield
      ensure
        Thread.current[:smolagents_test_mode] = was_enabled
      end

      # Returns the current test configuration.
      #
      # @return [TestConfiguration]
      def configuration
        @configuration ||= TestConfiguration.new
      end

      # Configures test mode settings.
      #
      # @yield [TestConfiguration] Configuration object
      # @return [self]
      def configure
        yield configuration if block_given?
        self
      end

      # Resets test mode configuration to defaults.
      #
      # @return [self]
      def reset!
        @configuration = TestConfiguration.new
        self
      end

      private

      def apply_test_defaults
        # Set thread-local flags for test-aware components
        Thread.current[:smolagents_no_network] = true
        Thread.current[:smolagents_verbose_events] = true
      end
    end

    # Test mode configuration options.
    #
    # @example Configure test mode
    #   Smolagents::Testing.configure do |config|
    #     config.verbose_logging = true
    #     config.record_call_logs = true
    #   end
    class TestConfiguration
      # Whether to emit verbose events during testing.
      # @return [Boolean]
      attr_accessor :verbose_logging

      # Whether to automatically record call logs for agents.
      # @return [Boolean]
      attr_accessor :record_call_logs

      # Whether to skip retry delays in tests.
      # @return [Boolean]
      attr_accessor :skip_retry_delays

      # Default timeout for operations in tests (milliseconds).
      # @return [Integer]
      attr_accessor :default_timeout_ms

      def initialize
        @verbose_logging = false
        @record_call_logs = true
        @skip_retry_delays = true
        @default_timeout_ms = 5000
      end
    end
  end
end
