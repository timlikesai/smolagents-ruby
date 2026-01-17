module Smolagents
  module Testing
    # Orthogonal capability dimensions for model testing.
    #
    # Unlike hierarchical test levels, capabilities are independent dimensions
    # that can be tested in any combination. A model might excel at tool_use
    # but lack vision capabilities, or have strong reasoning but weak code generation.
    #
    # @example Getting tests for a capability
    #   tests = Capabilities.for_capability(:tool_use)
    #   tests.map(&:name)  #=> [:single_tool, :multi_tool]
    #
    # @example Checking dimension metadata
    #   dim = Capabilities.dimension(:text)
    #   dim[:required]  #=> true
    #
    # @example Iterating all capabilities
    #   Capabilities.capabilities.each do |cap|
    #     puts "#{cap}: #{Capabilities.for_capability(cap).size} tests"
    #   end
    #
    # @see TestCase Individual test case definition
    # @see Validators Validation combinators for test assertions
    module Capabilities
      module_function

      # Orthogonal capability dimensions (not hierarchical levels!)
      DIMENSIONS = {
        text: { tests: [:basic_response], required: true },
        code: { tests: [:code_format], required: false },
        tool_use: { tests: %i[single_tool multi_tool], required: false },
        reasoning: { tests: [:reasoning], required: false },
        vision: { tests: %i[vision_basic vision_ocr], required: false }
      }.freeze

      # Test case registry - uses TestCase from test_case.rb
      REGISTRY = {
        basic_response: TestCase.new(
          name: "basic_response", capability: :text,
          task: "What is 2+2? Reply with just the number.",
          tools: [], validator: Validators.contains("4"),
          max_steps: 4, timeout: 30
        ),
        code_format: TestCase.new(
          name: "code_format", capability: :code,
          task: "Write Ruby code that prints 'Hello, World!'",
          tools: [], validator: Validators.all_of(
            Validators.code_block?,
            Validators.matches(/puts.*hello.*world/i)
          ),
          max_steps: 3, timeout: 30
        ),
        single_tool: TestCase.new(
          name: "single_tool", capability: :tool_use,
          task: "Use calculator to compute 25 * 4",
          tools: [:calculator], validator: Validators.contains("100"),
          max_steps: 5, timeout: 60
        ),
        multi_tool: TestCase.new(
          name: "multi_tool", capability: :tool_use,
          task: "Calculate (25 * 4) - 50 using the calculator",
          tools: [:calculator], validator: Validators.contains("50"),
          max_steps: 8, timeout: 90
        ),
        reasoning: TestCase.new(
          name: "reasoning", capability: :reasoning,
          task: "The year is 2020. Add 3 years. What year is it?",
          tools: [:calculator], validator: Validators.contains("2023"),
          max_steps: 6, timeout: 90
        ),
        vision_basic: TestCase.new(
          name: "vision_basic", capability: :vision,
          task: "Describe the main color in this image",
          tools: [], validator: Validators.matches(/red|blue|green|yellow/i),
          max_steps: 3, timeout: 60
        ),
        vision_ocr: TestCase.new(
          name: "vision_ocr", capability: :vision,
          task: "Read the text in this image",
          tools: [], validator: Validators.any_of(
            Validators.matches(/\w{4,}/),
            Validators.contains("text")
          ),
          max_steps: 3, timeout: 60
        )
      }.freeze

      # Retrieves a test case by key.
      #
      # @param key [Symbol] test case key
      # @return [TestCase] the test case
      # @raise [KeyError] if key not found
      def get(key) = REGISTRY.fetch(key)

      # Returns all registered test cases.
      #
      # @return [Array<TestCase>] all test cases
      def all = REGISTRY.values

      # Returns test cases for a specific capability.
      #
      # @param cap [Symbol] capability name
      # @return [Array<TestCase>] test cases for that capability
      def for_capability(cap) = REGISTRY.values.select { |tc| tc.capability == cap }

      # Returns all capability dimension names.
      #
      # @return [Array<Symbol>] capability names
      def capabilities = DIMENSIONS.keys

      # Retrieves dimension metadata.
      #
      # @param cap [Symbol] capability name
      # @return [Hash] dimension metadata with :tests and :required keys
      # @raise [KeyError] if capability not found
      def dimension(cap) = DIMENSIONS.fetch(cap)
    end
  end
end
