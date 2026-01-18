require "smolagents/testing"

RSpec.describe Smolagents::Testing::AgentSpec do
  describe "initialization" do
    it "creates spec with name" do
      spec = described_class.new(:research_assistant)

      expect(spec.name).to eq(:research_assistant)
    end

    it "defaults to empty capabilities" do
      spec = described_class.new(:test)

      expect(spec.capabilities).to eq([])
    end

    it "defaults constraints" do
      spec = described_class.new(:test)

      expect(spec.constraints).to eq({ max_steps: 10, reliability: 1.0 })
    end

    it "defaults to empty scenarios" do
      spec = described_class.new(:test)

      expect(spec.scenarios).to eq([])
    end
  end

  describe "#can" do
    it "adds a capability with tool name" do
      spec = described_class.new(:test)
                            .can(:search_web)

      expect(spec.capabilities).to eq([{ tool: :search_web, description: nil }])
    end

    it "adds a capability with description" do
      spec = described_class.new(:test)
                            .can(:search_web, "find information online")

      expect(spec.capabilities.first[:description]).to eq("find information online")
    end

    it "supports chaining" do
      spec = described_class.new(:test)
                            .can(:search_web)
                            .can(:read_documents)

      expect(spec.capabilities.size).to eq(2)
    end

    it "returns self for chaining" do
      spec = described_class.new(:test)
      result = spec.can(:search)

      expect(result).to be(spec)
    end
  end

  describe "#must_complete_in" do
    it "sets max steps constraint" do
      spec = described_class.new(:test)
                            .must_complete_in(steps: 8)

      expect(spec.constraints[:max_steps]).to eq(8)
    end

    it "returns self for chaining" do
      spec = described_class.new(:test)
      result = spec.must_complete_in(steps: 5)

      expect(result).to be(spec)
    end
  end

  describe "#must_achieve" do
    it "sets reliability constraint" do
      spec = described_class.new(:test)
                            .must_achieve(reliability: 0.95)

      expect(spec.constraints[:reliability]).to eq(0.95)
    end

    it "returns self for chaining" do
      spec = described_class.new(:test)
      result = spec.must_achieve(reliability: 0.9)

      expect(result).to be(spec)
    end
  end

  describe "#given" do
    it "adds a scenario" do
      spec = described_class.new(:test)
                            .given("a research question") { nil }

      expect(spec.scenarios.size).to eq(1)
      expect(spec.scenarios.first.description).to eq("a research question")
    end

    it "evaluates block in scenario context" do
      spec = described_class.new(:test)
                            .given("a test") do
                              when_asked "What is Ruby?"
      end

      expect(spec.scenarios.first.task).to eq("What is Ruby?")
    end

    it "returns self for chaining" do
      spec = described_class.new(:test)
      result = spec.given("test") { nil }

      expect(result).to be(spec)
    end
  end

  describe "#to_test_cases" do
    it "converts scenarios to test cases" do
      spec = described_class.new(:test)
                            .given("first scenario") { when_asked "Task 1" }
                            .given("second scenario") { when_asked "Task 2" }

      test_cases = spec.to_test_cases

      expect(test_cases.size).to eq(2)
      expect(test_cases).to all(be_a(Smolagents::Testing::TestCase))
    end

    it "returns empty array when no scenarios" do
      spec = described_class.new(:test)

      expect(spec.to_test_cases).to eq([])
    end
  end

  describe "#to_requirements" do
    it "returns a RequirementBuilder" do
      spec = described_class.new(:test)

      expect(spec.to_requirements).to be_a(Smolagents::Testing::RequirementBuilder)
    end

    it "sets name from spec" do
      spec = described_class.new(:my_agent)
      builder = spec.to_requirements
      suite = builder.build

      expect(suite.name).to eq(:my_agent)
    end

    it "sets reliability from constraints" do
      spec = described_class.new(:test)
                            .must_achieve(reliability: 0.8)

      builder = spec.to_requirements
      suite = builder.build

      expect(suite.reliability[:threshold]).to eq(0.8)
      expect(suite.reliability[:runs]).to eq(5)
    end

    it "adds tool_use requirement for capabilities" do
      spec = described_class.new(:test)
                            .can(:search_web)
                            .can(:read_docs)

      builder = spec.to_requirements

      # Each capability triggers requires(:tool_use) which adds 2 tests
      expect(builder.all_test_cases.size).to eq(4)
    end
  end

  describe "fluent DSL" do
    it "supports full fluent configuration" do
      spec = described_class.new(:research_assistant)
                            .can(:search_web, "find information")
                            .can(:read_documents, "extract content")
                            .must_complete_in(steps: 8)
                            .must_achieve(reliability: 0.95)
                            .given("a research question") do
                              when_asked "What is Ruby 4.0?"
                              should "search for information", using: :web_search
                              should "provide a summary", containing: ["pattern matching"]
                            end

      expect(spec.capabilities.size).to eq(2)
      expect(spec.constraints).to eq({ max_steps: 8, reliability: 0.95 })
      expect(spec.scenarios.size).to eq(1)
    end
  end
end

RSpec.describe Smolagents::Testing::Scenario do
  describe "initialization" do
    it "creates scenario with description" do
      scenario = described_class.new("a research question")

      expect(scenario.description).to eq("a research question")
    end

    it "defaults to nil task" do
      scenario = described_class.new("test")

      expect(scenario.task).to be_nil
    end

    it "defaults to empty expectations" do
      scenario = described_class.new("test")

      expect(scenario.expectations).to eq([])
    end
  end

  describe "#when_asked" do
    it "sets the task" do
      scenario = described_class.new("test")
                                .when_asked("What is Ruby?")

      expect(scenario.task).to eq("What is Ruby?")
    end

    it "returns self for chaining" do
      scenario = described_class.new("test")
      result = scenario.when_asked("task")

      expect(result).to be(scenario)
    end
  end

  describe "#should" do
    it "adds an expectation" do
      scenario = described_class.new("test")
                                .should("search for information")

      expect(scenario.expectations.size).to eq(1)
      expect(scenario.expectations.first[:description]).to eq("search for information")
    end

    it "adds expectation with tool" do
      scenario = described_class.new("test")
                                .should("search", using: :web_search)

      expect(scenario.expectations.first[:tool]).to eq(:web_search)
    end

    it "adds expectation with keywords" do
      scenario = described_class.new("test")
                                .should("contain keywords", containing: ["Ruby", "4.0"])

      expect(scenario.expectations.first[:keywords]).to eq(["Ruby", "4.0"])
    end

    it "returns self for chaining" do
      scenario = described_class.new("test")
      result = scenario.should("do something")

      expect(result).to be(scenario)
    end

    it "supports multiple expectations" do
      scenario = described_class.new("test")
                                .should("first thing")
                                .should("second thing")

      expect(scenario.expectations.size).to eq(2)
    end
  end

  describe "#should_not" do
    it "adds negated expectation" do
      scenario = described_class.new("test")
                                .should_not("fail silently")

      expect(scenario.expectations.first[:negated]).to be true
      expect(scenario.expectations.first[:description]).to eq("fail silently")
    end

    it "returns self for chaining" do
      scenario = described_class.new("test")
      result = scenario.should_not("fail")

      expect(result).to be(scenario)
    end
  end

  describe "#to_test_case" do
    it "returns a TestCase" do
      scenario = described_class.new("test scenario")
                                .when_asked("What is Ruby?")

      test_case = scenario.to_test_case

      expect(test_case).to be_a(Smolagents::Testing::TestCase)
    end

    it "generates name from description" do
      scenario = described_class.new("a research question")
                                .when_asked("task")

      test_case = scenario.to_test_case

      expect(test_case.name).to eq("scenario_a_research_question")
    end

    it "sets task from when_asked" do
      scenario = described_class.new("test")
                                .when_asked("What is Ruby 4.0?")

      test_case = scenario.to_test_case

      expect(test_case.task).to eq("What is Ruby 4.0?")
    end

    it "collects tools from expectations" do
      scenario = described_class.new("test")
                                .when_asked("task")
                                .should("search", using: :web_search)
                                .should("read", using: :read_doc)

      test_case = scenario.to_test_case

      expect(test_case.tools).to eq(%i[web_search read_doc])
    end

    it "sets default capability to :text" do
      scenario = described_class.new("test")
                                .when_asked("task")

      test_case = scenario.to_test_case

      expect(test_case.capability).to eq(:text)
    end

    it "sets default max_steps to 8" do
      scenario = described_class.new("test")
                                .when_asked("task")

      test_case = scenario.to_test_case

      expect(test_case.max_steps).to eq(8)
    end

    it "sets default timeout to 120" do
      scenario = described_class.new("test")
                                .when_asked("task")

      test_case = scenario.to_test_case

      expect(test_case.timeout).to eq(120)
    end

    describe "validator building" do
      it "returns truthy validator when no expectations" do
        scenario = described_class.new("test")
                                  .when_asked("task")

        test_case = scenario.to_test_case

        expect(test_case.validator.call("anything")).to be true
      end

      it "builds tool call validator" do
        scenario = described_class.new("test")
                                  .when_asked("task")
                                  .should("search", using: :web_search)

        test_case = scenario.to_test_case

        expect(test_case.validator.call("web_search(query: 'Ruby')")).to be true
        expect(test_case.validator.call("other_tool(arg: 1)")).to be false
      end

      it "builds keyword validator" do
        scenario = described_class.new("test")
                                  .when_asked("task")
                                  .should("contain info", containing: ["Ruby", "4.0"])

        test_case = scenario.to_test_case

        expect(test_case.validator.call("Ruby 4.0 features")).to be true
        expect(test_case.validator.call("Ruby features")).to be false
        expect(test_case.validator.call("4.0 features")).to be false
      end

      it "combines multiple validators with all_of" do
        scenario = described_class.new("test")
                                  .when_asked("task")
                                  .should("search", using: :search)
                                  .should("contain info", containing: ["Ruby"])

        test_case = scenario.to_test_case

        expect(test_case.validator.call("search(q: 'x') returns Ruby")).to be true
        expect(test_case.validator.call("search(q: 'x') returns nothing")).to be false
        expect(test_case.validator.call("Ruby info")).to be false
      end

      it "returns single validator directly" do
        scenario = described_class.new("test")
                                  .when_asked("task")
                                  .should("contain Ruby", containing: ["Ruby"])

        test_case = scenario.to_test_case

        # Single validator should work correctly
        expect(test_case.validator.call("Ruby is great")).to be true
        expect(test_case.validator.call("Python is great")).to be false
      end
    end
  end
end

RSpec.describe "Smolagents.agent_spec", type: :feature do
  it "creates an AgentSpec" do
    spec = Smolagents.agent_spec(:test)

    expect(spec).to be_a(Smolagents::Testing::AgentSpec)
    expect(spec.name).to eq(:test)
  end

  it "evaluates block in spec context" do
    spec = Smolagents.agent_spec(:test) do
      can :search_web
      must_complete_in steps: 5
    end

    expect(spec.capabilities.size).to eq(1)
    expect(spec.constraints[:max_steps]).to eq(5)
  end

  it "works without block" do
    spec = Smolagents.agent_spec(:empty)

    expect(spec.capabilities).to eq([])
    expect(spec.scenarios).to eq([])
  end

  it "supports full declarative definition" do
    spec = Smolagents.agent_spec :research_assistant do
      can :search_web, "find information online"
      can :read_documents, "extract content from URLs"

      must_complete_in steps: 8
      must_achieve reliability: 0.95

      given "a research question" do
        when_asked "What are the latest Ruby 4.0 features?"
        should "search for information", using: :web_search
        should "provide a summary", containing: ["pattern matching"]
      end
    end

    expect(spec.name).to eq(:research_assistant)
    expect(spec.capabilities.size).to eq(2)
    expect(spec.constraints).to eq({ max_steps: 8, reliability: 0.95 })
    expect(spec.scenarios.size).to eq(1)

    test_cases = spec.to_test_cases
    expect(test_cases.size).to eq(1)
    expect(test_cases.first.task).to eq("What are the latest Ruby 4.0 features?")
  end
end
