require "spec_helper"

RSpec.describe Smolagents::Testing::Matchers::AgentMatchers do
  describe ".included" do
    it "registers matchers when RSpec is defined" do
      test_module = Module.new
      test_module.include(described_class)
      expect(test_module).to include(described_class)
    end
  end

  describe "complete_successfully matcher" do
    let(:model) { Smolagents::Testing::MockModel.new }

    describe "with agent" do
      let(:agent) do
        model.queue_final_answer("done")
        Smolagents.agent.model { model }.build
      end

      it "passes when agent completes successfully" do
        expect(agent).to complete_successfully.with_task("test")
      end

      it "fails when agent returns nil" do
        failing_agent = double("Agent", run: nil)
        expect do
          expect(failing_agent).to complete_successfully.with_task("test")
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected agent to complete successfully/)
      end
    end

    describe "with result" do
      it "passes when result is not nil or exception" do
        expect("result").to complete_successfully
      end

      it "passes when result is a hash" do
        expect({ output: "42" }).to complete_successfully
      end

      it "fails when result is nil" do
        expect do
          expect(nil).to complete_successfully
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected agent to complete successfully/)
      end

      it "fails when result is an exception" do
        expect do
          expect(RuntimeError.new("error")).to complete_successfully
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected agent to complete successfully/)
      end
    end
  end
end
