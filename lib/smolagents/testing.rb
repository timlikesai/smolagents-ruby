# Ensure main library is loaded first for all dependencies
require "smolagents" unless defined?(Smolagents::Models::Model)

require_relative "testing/test_mode"
require_relative "testing/test_logger"
require_relative "testing/call_log"
require_relative "testing/call_log_support"
require_relative "testing/test_case"
require_relative "testing/test_result"
require_relative "testing/test_run"
require_relative "testing/test_runner"
require_relative "testing/result_store"
require_relative "testing/mock_model"
require_relative "testing/helpers"
require_relative "testing/matchers"
require_relative "testing/validators"
require_relative "testing/capabilities"
require_relative "testing/tool_execution_tests"
require_relative "testing/fixtures"
require_relative "testing/shared_examples"

module Smolagents
  # Testing utilities for smolagents.
  #
  # Provides MockModel, helpers, and matchers for deterministic agent testing.
  #
  # == Test Mode API
  #
  # Enable test mode globally for deterministic testing:
  #
  #   Smolagents.test_mode!
  #   agent = Smolagents.agent.model { mock }.build
  #   agent.run("task")
  #
  # Or scope it to a block:
  #
  #   Smolagents.test_mode do
  #     agent.run("task")
  #   end
  #
  # @see MockModel Deterministic model for testing
  # @see Helpers Helper methods for test setup
  # @see Matchers RSpec matchers for agents
  # @see CallLog Recording agent execution for assertions
  module Testing
    class << self
      # Configure RSpec with testing helpers and matchers.
      #
      # @param config [RSpec::Core::Configuration] RSpec configuration object
      # @return [void]
      def configure_rspec(config)
        config.include Helpers
        config.include Matchers
      end

      # Creates a new CallLog for recording agent execution.
      #
      # @return [CallLog]
      def call_log = CallLog.new

      # ============================================================
      # Test Mode API (delegated to TestMode)
      # ============================================================

      # Enables test mode globally.
      # @see TestMode#enable!
      def test_mode! = TestMode.enable!

      # Checks if test mode is enabled.
      # @see TestMode#test_mode?
      def test_mode? = TestMode.test_mode?

      # Executes a block in test mode.
      # @see TestMode#scope
      def test_mode(&) = TestMode.scope(&)

      # Returns test mode configuration.
      # @see TestMode#configuration
      def configuration = TestMode.configuration

      # Configures test mode settings.
      # @see TestMode#configure
      def configure(&) = TestMode.configure(&)

      # Resets test mode to defaults.
      # @see TestMode#reset!
      def reset! = TestMode.reset!
    end
  end

  # ============================================================
  # Top-level Test Mode DSL
  # ============================================================

  class << self
    # Enables test mode for deterministic agent testing.
    #
    # When test mode is enabled:
    # - Network requests are blocked by default
    # - Verbose events are emitted for debugging
    # - Call logs are automatically recorded
    #
    # @return [Testing::TestMode]
    #
    # @example Enable test mode
    #   Smolagents.test_mode!
    #   # Now all agents run in test mode
    #
    # @see Testing::TestMode For configuration options
    def test_mode! = Testing.test_mode!

    # Checks if test mode is currently enabled.
    #
    # @return [Boolean]
    def test_mode? = Testing.test_mode?

    # Executes a block in test mode.
    #
    # Test mode is automatically disabled after the block completes,
    # even if an exception is raised. Use this for isolated tests.
    #
    # @yield Block to execute in test mode
    # @return [Object] Result of the block
    #
    # @example Scoped test mode
    #   Smolagents.test_mode { :test_mode_active }
    #   # Test mode is now disabled
    def test_mode(&) = Testing.test_mode(&)
  end
end
