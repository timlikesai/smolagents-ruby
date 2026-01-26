module Smolagents
  module Testing
    # Orthogonal capability dimensions for model testing.
    #
    # Capabilities are independent dimensions that can be tested in any combination.
    # A model might excel at tool_use but lack vision capabilities, or have strong
    # reasoning but weak code generation.
    #
    # The registry is extensible - register custom capabilities at runtime:
    #
    # @example Getting tests for a capability
    #   tests = Capabilities.for_capability(:tool_use)
    #   tests.map(&:name)  #=> [:single_tool, :multi_tool, ...]
    #
    # @example Register a custom capability
    #   Capabilities.register(:my_capability,
    #     name: "my_test",
    #     task: "Do something",
    #     validator: ->(r) { r.include?("done") }
    #   )
    #
    # @example Check if a capability exists
    #   Capabilities.capability?(:tool_use)  #=> true
    #
    # @see TestCase Individual test case definition
    # @see Validators Validation combinators for test assertions
    module Capabilities
      # Mutable registries for extensibility
      @dimensions = {}
      @registry = {}
      @mutex = Mutex.new
      @reset_callbacks = []

      class << self
        # Register a new test case under a capability.
        #
        # @param capability [Symbol] The capability dimension
        # @param name [String, Symbol] Unique test name
        # @param task [String] The task prompt
        # @param tools [Array<Symbol>] Required tools
        # @param validator [Proc] Validation proc
        # @param max_steps [Integer] Maximum steps (default: 5)
        # @param timeout [Integer] Timeout in seconds (default: 60)
        # @return [TestCase] The registered test case
        def register(capability, name:, task:, tools: [], validator: nil, max_steps: 5, timeout: 60)
          test_case = build_test_case(name:, capability:, task:, tools:, validator:, max_steps:, timeout:)
          store_test_case(test_case, capability, name)
          test_case
        end

        private

        def build_test_case(name:, capability:, task:, tools:, validator:, max_steps:, timeout:)
          TestCase.new(name: name.to_s, capability:, task:, tools:, validator:, max_steps:, timeout:)
        end

        def store_test_case(test_case, capability, name)
          @mutex.synchronize do
            @registry[name.to_sym] = test_case
            @dimensions[capability] ||= { tests: [], required: false }
            @dimensions[capability][:tests] << name.to_sym unless @dimensions[capability][:tests].include?(name.to_sym)
          end
        end

        public

        # Retrieves a test case by key.
        #
        # @param key [Symbol] test case key
        # @return [TestCase] the test case
        # @raise [KeyError] if key not found
        def get(key) = @registry.fetch(key.to_sym)

        # Check if a test exists.
        #
        # @param key [Symbol] test case key
        # @return [Boolean]
        def test?(key) = @registry.key?(key.to_sym)

        # Returns all registered test cases.
        #
        # @return [Array<TestCase>] all test cases
        def all = @registry.values

        # Returns test cases for a specific capability.
        #
        # @param cap [Symbol] capability name
        # @return [Array<TestCase>] test cases for that capability
        def for_capability(cap)
          @registry.values.select { |tc| tc.capability == cap }
        end

        # Returns all capability dimension names.
        #
        # @return [Array<Symbol>] capability names
        def capabilities = @dimensions.keys

        # Check if a capability exists.
        #
        # @param cap [Symbol] capability name
        # @return [Boolean]
        def capability?(cap) = @dimensions.key?(cap)

        # Retrieves dimension metadata.
        #
        # @param cap [Symbol] capability name
        # @return [Hash] dimension metadata with :tests and :required keys
        # @raise [KeyError] if capability not found
        def dimension(cap) = @dimensions.fetch(cap)

        # Register a callback to run after reset! restores state.
        # Use this for extension modules that register capabilities.
        #
        # @example
        #   Capabilities.on_reset { MyModule.register_capabilities! }
        #
        # @yield Block to execute after reset
        # @api private
        def on_reset(&block)
          @reset_callbacks << block
        end

        # Clear all registrations (for testing).
        # Restores core capabilities and calls registered reset callbacks.
        # @api private
        def reset!
          @mutex.synchronize do
            @dimensions.clear
            @registry.clear
          end
          register_core_capabilities
          @reset_callbacks.each(&:call)
        end

        # Register the core capabilities (called on load).
        # @api private
        def register_core_capabilities
          register_text_capability
          register_code_capability
          register_tool_use_capabilities
          register_reasoning_capability
          register_vision_capabilities
          @dimensions[:text][:required] = true
        end

        def register_text_capability
          register(:text, name: "basic_response", task: "What is 2+2? Reply with just the number.",
                          validator: Validators.contains("4"), max_steps: 4, timeout: 30)
        end

        def register_code_capability
          validator = Validators.all_of(Validators.code_block?, Validators.matches(/puts.*hello.*world/i))
          register(:code, name: "code_format", task: "Write Ruby code that prints 'Hello, World!'",
                          validator:, max_steps: 3, timeout: 30)
        end

        def register_tool_use_capabilities
          register(:tool_use, name: "single_tool", task: "Use calculator to compute 25 * 4",
                              tools: [:calculator], validator: Validators.contains("100"), max_steps: 5, timeout: 60)
          register(:tool_use, name: "multi_tool", task: "Calculate (25 * 4) - 50 using the calculator",
                              tools: [:calculator], validator: Validators.contains("50"), max_steps: 8, timeout: 90)
        end

        def register_reasoning_capability
          register(:reasoning, name: "reasoning", task: "The year is 2020. Add 3 years. What year is it?",
                               tools: [:calculator], validator: Validators.contains("2023"), max_steps: 6, timeout: 90)
        end

        def register_vision_capabilities
          register(:vision, name: "vision_basic", task: "Describe the main color in this image",
                            validator: Validators.matches(/red|blue|green|yellow/i), max_steps: 3, timeout: 60)
          register(:vision, name: "vision_ocr", task: "Read the text in this image",
                            validator: Validators.any_of(Validators.matches(/\w{4,}/), Validators.contains("text")),
                            max_steps: 3, timeout: 60)
        end
      end

      # Initialize core capabilities on load
      register_core_capabilities
    end
  end
end
