require "spec_helper"

RSpec.describe Smolagents::Testing::ModelBenchmark::TestDefinitions do
  # Create a test class that includes the TestDefinitions module
  let(:test_class) do
    Class.new do
      include Smolagents::Testing::ModelBenchmark::TestDefinitions
    end
  end

  let(:definitions) { test_class.new }

  describe "#tests_for_level" do
    context "level 1 - basic response" do
      it "returns basic_response test" do
        tests = definitions.tests_for_level(1)

        expect(tests.size).to eq(1)
        expect(tests.first[:name]).to eq("basic_response")
        expect(tests.first[:level]).to eq(1)
        expect(tests.first[:type]).to eq(:chat)
      end

      it "validates response containing '4'" do
        test = definitions.tests_for_level(1).first

        expect(test[:validator].call("The answer is 4")).to be true
        expect(test[:validator].call("Four")).to be false
        expect(test[:validator].call("42")).to be true
      end
    end

    context "level 2 - code format" do
      it "returns code_format test" do
        tests = definitions.tests_for_level(2)

        expect(tests.size).to eq(1)
        expect(tests.first[:name]).to eq("code_format")
        expect(tests.first[:level]).to eq(2)
        expect(tests.first[:type]).to eq(:chat)
      end

      it "validates proper code block with hello world" do
        test = definitions.tests_for_level(2).first

        valid_response = <<~RESPONSE
          Here's the code:
          ```ruby
          puts "hello world"
          ```
        RESPONSE

        expect(test[:validator].call(valid_response)).to be true
      end

      it "rejects response without code block" do
        test = definitions.tests_for_level(2).first

        expect(test[:validator].call('puts "hello world"')).to be false
      end

      it "rejects code block without hello world" do
        test = definitions.tests_for_level(2).first

        response = <<~RESPONSE
          ```ruby
          puts "goodbye"
          ```
        RESPONSE

        expect(test[:validator].call(response)).to be false
      end

      it "accepts print variant" do
        test = definitions.tests_for_level(2).first

        response = <<~RESPONSE
          ```ruby
          print "hello world"
          ```
        RESPONSE

        expect(test[:validator].call(response)).to be true
      end
    end

    context "level 3 - tool calling" do
      it "returns single_tool_call test" do
        tests = definitions.tests_for_level(3)

        expect(tests.size).to eq(1)
        expect(tests.first[:name]).to eq("single_tool_call")
        expect(tests.first[:level]).to eq(3)
        expect(tests.first[:type]).to eq(:agent)
        expect(tests.first[:tools]).to eq([:calculator])
        expect(tests.first[:max_steps]).to eq(5)
      end

      it "validates successful result containing 105" do
        test = definitions.tests_for_level(3).first
        mock_result = double(success?: true, output: "The result is 105")

        expect(test[:validator].call(mock_result)).to be true
      end

      it "rejects failed result" do
        test = definitions.tests_for_level(3).first
        mock_result = double(success?: false, output: "105")

        expect(test[:validator].call(mock_result)).to be false
      end
    end

    context "level 4 - multi-step" do
      it "returns multi_step_task test" do
        tests = definitions.tests_for_level(4)

        expect(tests.size).to eq(1)
        expect(tests.first[:name]).to eq("multi_step_task")
        expect(tests.first[:level]).to eq(4)
        expect(tests.first[:type]).to eq(:agent)
        expect(tests.first[:max_steps]).to eq(8)
      end

      it "validates result containing 50" do
        test = definitions.tests_for_level(4).first
        # 25 * 4 = 100, 100 - 50 = 50
        mock_result = double(success?: true, output: "The final answer is 50")

        expect(test[:validator].call(mock_result)).to be true
      end
    end

    context "level 5 - complex reasoning" do
      it "returns complex_reasoning test" do
        tests = definitions.tests_for_level(5)

        expect(tests.size).to eq(1)
        expect(tests.first[:name]).to eq("complex_reasoning")
        expect(tests.first[:level]).to eq(5)
        expect(tests.first[:type]).to eq(:agent)
        expect(tests.first[:max_steps]).to eq(6)
      end

      it "validates result containing 2023" do
        test = definitions.tests_for_level(5).first
        # 2020 + 3 = 2023
        mock_result = double(success?: true, output: "Ruby 4.0 will be released in 2023")

        expect(test[:validator].call(mock_result)).to be true
      end
    end

    context "level 6 - vision" do
      it "returns vision_test" do
        tests = definitions.tests_for_level(6)

        expect(tests.size).to eq(1)
        expect(tests.first[:name]).to eq("vision_test")
        expect(tests.first[:level]).to eq(6)
        expect(tests.first[:type]).to eq(:vision)
        expect(tests.first[:image_url]).to include("ruby-lang.org")
      end

      it "validates response mentioning red" do
        test = definitions.tests_for_level(6).first

        expect(test[:validator].call("I see a red gem")).to be true
        expect(test[:validator].call("I see a RED logo")).to be true
        expect(test[:validator].call("It's blue")).to be false
      end
    end

    context "invalid level" do
      it "returns empty array for level 0" do
        expect(definitions.tests_for_level(0)).to eq([])
      end

      it "returns empty array for level 7" do
        expect(definitions.tests_for_level(7)).to eq([])
      end

      it "returns empty array for negative level" do
        expect(definitions.tests_for_level(-1)).to eq([])
      end
    end
  end

  describe "LEVEL2_PROMPT constant" do
    it "asks for Ruby code in a code block" do
      prompt = Smolagents::Testing::ModelBenchmark::TestDefinitions::LEVEL2_PROMPT

      expect(prompt).to include("Ruby code")
      expect(prompt).to include("hello world")
      expect(prompt).to include("```ruby")
    end
  end

  describe "LEVEL4_TASK constant" do
    it "describes multi-step calculation" do
      task = Smolagents::Testing::ModelBenchmark::TestDefinitions::LEVEL4_TASK

      expect(task).to include("25 * 4")
      expect(task).to include("subtract 50")
      expect(task).to include("final_answer")
    end
  end

  describe "LEVEL5_TASK constant" do
    it "describes reasoning about Ruby release dates" do
      task = Smolagents::Testing::ModelBenchmark::TestDefinitions::LEVEL5_TASK

      expect(task).to include("Ruby 3.0")
      expect(task).to include("2020")
      expect(task).to include("Ruby 4.0")
      expect(task).to include("calculate")
    end
  end
end
