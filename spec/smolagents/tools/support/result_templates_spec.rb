require "spec_helper"

RSpec.describe Smolagents::Tools::Support::ResultTemplates do
  describe "DSL methods" do
    let(:test_class) do
      Class.new do
        include Smolagents::Tools::Support::ResultTemplates

        empty_message "No items found."
        next_steps_message "Try different terms."
        success_header "Discovered %<count>s %<noun>s"
      end
    end

    let(:instance) { test_class.new }

    describe ".empty_message" do
      it "defines empty_result_message method" do
        expect(instance.empty_result_message).to eq("No items found.")
      end
    end

    describe ".next_steps_message" do
      it "defines next_steps_message method" do
        expect(instance.next_steps_message).to eq("Try different terms.")
      end
    end

    describe ".success_header" do
      it "defines success_header_template method" do
        expect(instance.success_header_template).to eq("Discovered %<count>s %<noun>s")
      end
    end
  end

  describe "default methods" do
    let(:test_class) do
      Class.new do
        include Smolagents::Tools::Support::ResultTemplates
      end
    end

    let(:instance) { test_class.new }

    it "provides default empty_result_message" do
      expect(instance.empty_result_message).to eq("No results found.")
    end

    it "provides default next_steps_message as nil" do
      expect(instance.next_steps_message).to be_nil
    end

    it "provides default success_header_template" do
      expect(instance.success_header_template).to eq("Found %<count>s %<noun>s")
    end
  end

  describe "#format_success_header" do
    let(:test_class) do
      Class.new do
        include Smolagents::Tools::Support::ResultTemplates
      end
    end

    let(:instance) { test_class.new }

    it "formats singular count correctly" do
      expect(instance.format_success_header(1)).to eq("Found 1 result")
    end

    it "formats plural count correctly" do
      expect(instance.format_success_header(5)).to eq("Found 5 results")
    end

    it "accepts custom noun" do
      expect(instance.format_success_header(3, noun: "article")).to eq("Found 3 articles")
    end

    it "handles singular custom noun" do
      expect(instance.format_success_header(1, noun: "paper")).to eq("Found 1 paper")
    end
  end

  describe "custom template with format_success_header" do
    let(:test_class) do
      Class.new do
        include Smolagents::Tools::Support::ResultTemplates

        success_header "Located %<count>s %<noun>s"
      end
    end

    let(:instance) { test_class.new }

    it "uses custom template" do
      expect(instance.format_success_header(2, noun: "item")).to eq("Located 2 items")
    end
  end
end
