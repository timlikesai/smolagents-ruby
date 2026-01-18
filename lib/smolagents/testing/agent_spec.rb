module Smolagents
  module Testing
    # Declarative DSL for specifying agent behavior.
    #
    # @example Define agent behavior
    #   Smolagents.agent_spec :research_assistant do
    #     can :search_web, "find information online"
    #     can :read_documents, "extract content from URLs"
    #
    #     must_complete_in steps: 8
    #     must_achieve reliability: 0.95
    #
    #     given "a research question" do
    #       when_asked "What are the latest Ruby 4.0 features?"
    #       should "search for information", using: :web_search
    #       should "provide a summary", containing: ["pattern matching"]
    #     end
    #   end
    class AgentSpec
      attr_reader :name, :capabilities, :constraints, :scenarios

      def initialize(name)
        @name = name
        @capabilities = []
        @constraints = { max_steps: 10, reliability: 1.0 }
        @scenarios = []
      end

      # Declare a capability the agent has
      def can(tool_name, description = nil)
        @capabilities << { tool: tool_name, description: }
        self
      end

      # Set max steps constraint
      def must_complete_in(steps:)
        @constraints[:max_steps] = steps
        self
      end

      # Set reliability constraint
      def must_achieve(reliability:)
        @constraints[:reliability] = reliability
        self
      end

      # Define a test scenario
      def given(description, &block)
        scenario = Scenario.new(description)
        scenario.instance_eval(&block) if block
        @scenarios << scenario
        self
      end

      # Generate test cases from this spec
      def to_test_cases
        @scenarios.map(&:to_test_case)
      end

      # Generate a RequirementBuilder from this spec
      def to_requirements
        builder = RequirementBuilder.new(@name)
        @capabilities.each { |cap| builder.requires(:tool_use) if cap[:tool] }
        builder.reliability(runs: 5, threshold: @constraints[:reliability])
        builder
      end
    end

    # A single test scenario within an agent spec
    class Scenario
      attr_reader :description, :task, :expectations

      def initialize(description)
        @description = description
        @task = nil
        @expectations = []
      end

      def when_asked(task)
        @task = task
        self
      end

      def should(description, using: nil, containing: nil)
        @expectations << {
          description:,
          tool: using,
          keywords: containing
        }
        self
      end

      def should_not(description)
        @expectations << { description:, negated: true }
        self
      end

      def to_test_case
        validator = build_validator
        TestCase.new(
          name: "scenario_#{description.downcase.gsub(/\s+/, "_")}",
          capability: :text,
          task: @task,
          tools: @expectations.filter_map { |e| e[:tool] },
          validator:,
          max_steps: 8,
          timeout: 120
        )
      end

      private

      def build_validator
        validators = @expectations.filter_map do |exp|
          if exp[:keywords]
            Validators.all_of(*exp[:keywords].map { |k| Validators.contains(k) })
          elsif exp[:tool]
            Validators.calls_tool(exp[:tool].to_s)
          end
        end

        return ->(_) { true } if validators.empty?

        validators.size == 1 ? validators.first : Validators.all_of(*validators)
      end
    end
  end

  class << self
    # Define an agent specification
    def agent_spec(name, &block)
      spec = Testing::AgentSpec.new(name)
      spec.instance_eval(&block) if block
      spec
    end
  end
end
