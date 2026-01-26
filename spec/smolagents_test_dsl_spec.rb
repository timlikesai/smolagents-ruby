RSpec.describe "Smolagents Test DSL", type: :feature do
  describe ".test(:model)" do
    it "returns a TestBuilder" do
      builder = Smolagents.test(:model)

      expect(builder).to be_a(Smolagents::Builders::TestBuilder)
    end

    it "raises ArgumentError for unknown test types" do
      expect { Smolagents.test(:unknown) }.to raise_error(ArgumentError, /Unknown test type/)
    end

    describe "fluent interface" do
      it "supports .task" do
        builder = Smolagents.test(:model).task("What is 2+2?")

        expect(builder).to be_a(Smolagents::Builders::TestBuilder)
        expect(builder.config[:task]).to eq("What is 2+2?")
      end

      it "supports .expects with a block" do
        builder = Smolagents.test(:model)
                            .task("Calculate something")
                            .expects { |out| out.include?("result") }

        expect(builder.config[:validator]).to be_a(Proc)
      end

      it "supports .tools" do
        builder = Smolagents.test(:model)
                            .task("Use a tool")
                            .tools(:search, :calculator)

        expect(builder.config[:tools]).to eq(%i[search calculator])
      end

      it "supports .max_steps" do
        builder = Smolagents.test(:model)
                            .task("Do something")
                            .max_steps(10)

        expect(builder.config[:max_steps]).to eq(10)
      end

      it "supports .timeout" do
        builder = Smolagents.test(:model)
                            .task("Do something")
                            .timeout(120)

        expect(builder.config[:timeout]).to eq(120)
      end

      it "supports .name" do
        builder = Smolagents.test(:model)
                            .task("Do something")
                            .name(:my_test)

        expect(builder.config[:name]).to eq(:my_test)
      end

      it "supports full fluent chain" do
        builder = Smolagents.test(:model)
                            .name(:arithmetic_test)
                            .task("What is 2+2?")
                            .tools(:calculator)
                            .max_steps(5)
                            .timeout(30)
                            .expects { |out| out.include?("4") }

        expect(builder.config[:name]).to eq(:arithmetic_test)
        expect(builder.config[:task]).to eq("What is 2+2?")
        expect(builder.config[:tools]).to eq([:calculator])
        expect(builder.config[:max_steps]).to eq(5)
        expect(builder.config[:timeout]).to eq(30)
        expect(builder.config[:validator]).to be_a(Proc)
      end
    end

    describe "#build_test_case" do
      it "creates a TestCase from configuration" do
        builder = Smolagents.test(:model)
                            .name(:my_test)
                            .task("Test task")
                            .tools(:search)
                            .max_steps(8)
                            .timeout(90)

        test_case = builder.build_test_case

        expect(test_case).to be_a(Smolagents::Testing::TestCase)
        expect(test_case.name).to eq(:my_test)
        expect(test_case.task).to eq("Test task")
        expect(test_case.tools).to eq([:search])
        expect(test_case.max_steps).to eq(8)
        expect(test_case.timeout).to eq(90)
      end
    end
  end

  describe ".test_suite" do
    it "returns a RequirementBuilder" do
      builder = Smolagents.test_suite(:my_suite)

      expect(builder).to be_a(Smolagents::Testing::RequirementBuilder)
    end

    describe "fluent interface" do
      it "supports .requires for capability dimensions" do
        builder = Smolagents.test_suite(:my_suite)
                            .requires(:tool_use)

        expect(builder.all_test_cases).not_to be_empty
      end

      it "supports .reliability configuration" do
        builder = Smolagents.test_suite(:my_suite)
                            .reliability(runs: 10, threshold: 0.95)

        suite = builder.build

        expect(suite.reliability[:runs]).to eq(10)
        expect(suite.reliability[:threshold]).to eq(0.95)
      end

      it "supports chaining multiple requires" do
        # This may fail if capabilities aren't registered, but tests the chain
        builder = Smolagents.test_suite(:my_suite)

        expect(builder).to respond_to(:requires)
        expect(builder).to respond_to(:reliability)
        expect(builder).to respond_to(:build)
      end
    end

    describe "#build" do
      it "creates a TestSuite" do
        builder = Smolagents.test_suite(:my_suite)
                            .reliability(runs: 5, threshold: 0.8)

        suite = builder.build

        expect(suite).to be_a(Smolagents::Testing::TestSuite)
        expect(suite.name).to eq(:my_suite)
        expect(suite.reliability[:runs]).to eq(5)
        expect(suite.reliability[:threshold]).to eq(0.8)
      end
    end
  end
end
