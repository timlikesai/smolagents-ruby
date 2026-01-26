module Smolagents
  module Testing
    # Immutable test case definition for model testing.
    #
    # Defines a single test scenario including the task prompt, required tools,
    # validation logic, and execution constraints. Use with ModelBenchmark to
    # evaluate model capabilities.
    #
    # @example Basic test case
    #   test = TestCase.new(
    #     name: "simple_arithmetic",
    #     capability: :basic_reasoning,
    #     task: "What is 2 + 2?"
    #   )
    #
    # @example With validation
    #   test = TestCase.new(
    #     name: "search_test",
    #     capability: :tool_use,
    #     task: "Search for Ruby 4.0 release date",
    #     tools: [:search],
    #     validator: ->(result) { result.include?("2024") }
    #   )
    #
    # @example Fluent modification
    #   test = TestCase.new(name: "test", capability: :reasoning, task: "Do something")
    #     .with_tools(:search, :web)
    #     .with_timeout(120)
    #     .with_validator(->(r) { r.success? })
    #
    # @see ModelBenchmark
    TestCase = Data.define(:name, :capability, :task, :tools, :validator, :max_steps, :timeout) do
      # Creates a new TestCase with default values.
      #
      # @param name [String, Symbol] Unique identifier for this test
      # @param capability [Symbol] The capability being tested (e.g., :reasoning, :tool_use)
      # @param task [String] The prompt/task to give the agent
      # @param tools [Array<Symbol>] Tool names required for this test (default: [])
      # @param validator [Proc, nil] Validation proc that receives result (default: nil)
      # @param max_steps [Integer] Maximum agent steps allowed (default: 5)
      # @param timeout [Integer] Timeout in seconds (default: 60)
      def initialize(name:, capability:, task:, tools: [], validator: nil, max_steps: 5, timeout: 60)
        super
      end

      # Returns a new TestCase with the given validator.
      #
      # @param proc [Proc] Validation proc that receives the result
      # @return [TestCase] New instance with updated validator
      def with_validator(proc) = with(validator: proc)

      # Returns a new TestCase with the given timeout.
      #
      # @param seconds [Integer] Timeout in seconds
      # @return [TestCase] New instance with updated timeout
      def with_timeout(seconds) = with(timeout: seconds)

      # Returns a new TestCase with the given tools.
      #
      # @param tool_names [Array<Symbol>] Tool names
      # @return [TestCase] New instance with updated tools
      def with_tools(*tool_names) = with(tools: tool_names.flatten)

      # Returns a new TestCase with the given max steps.
      #
      # @param count [Integer] Maximum steps
      # @return [TestCase] New instance with updated max_steps
      def with_max_steps(count) = with(max_steps: count)

      # Converts to a hash representation (excludes validator).
      #
      # @return [Hash] Hash with all fields except validator
      def to_h = { name:, capability:, task:, tools:, max_steps:, timeout: }

      # Enables pattern matching with hash patterns.
      #
      # @param _ [Array, nil] Ignored
      # @return [Hash] Hash representation for pattern matching
      def deconstruct_keys(_) = to_h
    end
  end
end
