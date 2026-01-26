require "spec_helper"

RSpec.describe Smolagents::Testing::Matchers::ResultMatchers do
  describe ".included" do
    it "registers matchers when RSpec is defined" do
      test_module = Module.new
      test_module.include(described_class)
      expect(test_module).to include(described_class)
    end
  end

  describe "have_output matcher" do
    describe "with string result" do
      it "passes when output contains substring" do
        result = "The answer is 42"
        expect(result).to have_output(containing: "42")
      end

      it "fails when output does not contain substring" do
        result = "The answer is 42"
        expect do
          expect(result).to have_output(containing: "99")
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected result to have output matching/)
      end

      it "passes when output matches pattern" do
        result = "Answer: 42"
        expect(result).to have_output(matching: /\d+/)
      end

      it "fails when output does not match pattern" do
        result = "No numbers here"
        expect do
          expect(result).to have_output(matching: /\d+/)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected result to have output matching/)
      end

      it "supports both containing and matching" do
        result = "Answer: 42"
        expect(result).to have_output(containing: "Answer", matching: /\d+/)
      end
    end

    describe "with hash result" do
      it "extracts output from symbol key" do
        result = { output: "result 42" }
        expect(result).to have_output(containing: "42")
      end

      it "extracts output from string key" do
        result = { "output" => "result 42" }
        expect(result).to have_output(containing: "42")
      end
    end

    describe "with object result" do
      let(:result_object) do
        Data.define(:output).new("object output 42")
      end

      it "extracts output via method call" do
        expect(result_object).to have_output(containing: "42")
      end
    end

    describe "with object without output method" do
      it "uses to_s as fallback" do
        obj = Object.new
        def obj.to_s = "stringified 42"
        expect(obj).to have_output(containing: "42")
      end
    end
  end

  describe "have_steps matcher" do
    let(:result_with_steps) do
      steps = [double("Step1"), double("Step2"), double("Step3")]
      Data.define(:steps).new(steps)
    end

    let(:result_without_steps) do
      Data.define(:other).new("value")
    end

    describe "with exact count" do
      it "passes when step count matches" do
        expect(result_with_steps).to have_steps(3)
      end

      it "fails when step count differs" do
        expect do
          expect(result_with_steps).to have_steps(5)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected 5 steps but got 3/)
      end
    end

    describe "with at_most constraint" do
      it "passes when steps at or below limit" do
        expect(result_with_steps).to have_steps(at_most: 5)
        expect(result_with_steps).to have_steps(at_most: 3)
      end

      it "fails when steps exceed limit" do
        expect do
          expect(result_with_steps).to have_steps(at_most: 2)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected.*at_most.*steps but got 3/)
      end
    end

    describe "with at_least constraint" do
      it "passes when steps at or above minimum" do
        expect(result_with_steps).to have_steps(at_least: 2)
        expect(result_with_steps).to have_steps(at_least: 3)
      end

      it "fails when steps below minimum" do
        expect do
          expect(result_with_steps).to have_steps(at_least: 5)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected.*at_least.*steps but got 3/)
      end
    end

    describe "with combined constraints" do
      it "passes when both constraints satisfied" do
        expect(result_with_steps).to have_steps(at_least: 2, at_most: 5)
      end

      it "fails when at_least not satisfied" do
        expect do
          expect(result_with_steps).to have_steps(at_least: 10, at_most: 20)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected.*steps but got 3/)
      end

      it "fails when at_most not satisfied" do
        expect do
          expect(result_with_steps).to have_steps(at_least: 1, at_most: 2)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected.*steps but got 3/)
      end
    end

    describe "with object without steps method" do
      it "treats as empty steps array" do
        expect(result_without_steps).to have_steps(0)
      end

      it "fails for non-zero count" do
        expect do
          expect(result_without_steps).to have_steps(1)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected 1 steps but got 0/)
      end
    end
  end
end
