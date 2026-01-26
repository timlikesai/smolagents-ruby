module Smolagents
  module Testing
    # Builder for creating custom test cases.
    #
    # Uses metaprogramming to generate fluent setter methods for common attributes.
    # Each setter returns self for chaining, and #build creates an immutable TestCase.
    #
    # @example
    #   builder = TestCaseBuilder.new("my_test")
    #   builder.capability(:reasoning)
    #   builder.task("What is 2 + 2?")
    #   builder.validator(->(r) { r.include?("4") })
    #   test_case = builder.build
    class TestCaseBuilder
      # Attribute definitions: name => default value
      DEFAULTS = {
        capability: :custom,
        task: "",
        tools: [],
        validator: nil,
        max_steps: 5,
        timeout: 60
      }.freeze

      def initialize(name)
        @name = name
        @attributes = DEFAULTS.dup
      end

      # Generate fluent setters for simple attributes
      %i[capability task validator max_steps timeout].each do |attr|
        define_method(attr) do |value|
          @attributes[attr] = value
          self
        end
      end

      # Set required tools.
      #
      # @param tool_names [Array<Symbol>] Tool names
      # @return [self] For method chaining
      def tools(*tool_names)
        @attributes[:tools] = tool_names.flatten
        self
      end

      # Build the test case.
      #
      # @return [TestCase] The configured test case
      def build
        TestCase.new(name: @name, **@attributes)
      end
    end
  end
end
