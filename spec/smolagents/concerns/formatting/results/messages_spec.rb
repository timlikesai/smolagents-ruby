require "spec_helper"

RSpec.describe Smolagents::Concerns::Results::Messages do
  subject(:messager) { test_class.new }

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Results::Messages
    end
  end

  describe "constants" do
    it "defines EMPTY_RESULTS_MESSAGE" do
      msg = Smolagents::Concerns::Results::Messages::EMPTY_RESULTS_MESSAGE
      expect(msg).to be_a(String)
      expect(msg).to include("No results")
    end

    it "defines RESULTS_NEXT_STEPS" do
      msg = Smolagents::Concerns::Results::Messages::RESULTS_NEXT_STEPS
      expect(msg).to be_a(String)
      expect(msg).to include("NEXT STEPS")
    end

    it "defines MESSAGE_TEMPLATES hash" do
      templates = Smolagents::Concerns::Results::Messages::MESSAGE_TEMPLATES
      expect(templates).to be_a(Hash)
      expect(templates[:empty]).to include("No results")
    end
  end

  describe "#empty_results_message" do
    it "returns the EMPTY_RESULTS_MESSAGE" do
      result = messager.send(:empty_results_message)
      expect(result).to include("No results")
    end
  end

  describe "#build_results_output" do
    it "includes result count in header" do
      output = messager.send(:build_results_output, 5, "Results", %w[item1 item2])
      expect(output).to include("5")
    end

    it "uses custom header when provided" do
      output = messager.send(:build_results_output, 3, "My Custom Header", %w[a b])
      expect(output).to include("My Custom Header")
    end

    it "concatenates formatted results" do
      output = messager.send(:build_results_output, 2, "Header", %w[line1 line2])
      expect(output).to include("line1")
      expect(output).to include("line2")
    end

    it "includes next steps message" do
      output = messager.send(:build_results_output, 1, "Header", ["result"])
      expect(output).to include("NEXT STEPS")
    end

    it "handles empty formatted results" do
      output = messager.send(:build_results_output, 0, "Header", [])
      expect(output).to be_a(String)
    end
  end

  describe "#results_next_steps" do
    it "returns next steps guidance" do
      result = messager.send(:results_next_steps)
      expect(result).to include("NEXT STEPS")
    end
  end
end
