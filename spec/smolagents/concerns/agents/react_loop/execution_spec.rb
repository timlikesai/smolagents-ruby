require "smolagents/concerns/agents/react_loop/execution"

RSpec.describe Smolagents::Concerns::ReActLoop::Execution do
  describe ".included" do
    let(:test_class) { Class.new }

    before do
      test_class.include(described_class)
    end

    it "includes Completion module" do
      expect(test_class.included_modules).to include(Smolagents::Concerns::ReActLoop::Completion)
    end

    it "includes Loop module" do
      expect(test_class.included_modules).to include(Smolagents::Concerns::ReActLoop::Execution::Loop)
    end

    it "includes Monitoring module" do
      expect(test_class.included_modules).to include(Smolagents::Concerns::ReActLoop::Execution::Monitoring)
    end
  end

  describe "composition" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ReActLoop::Execution
      end
    end

    it "provides fiber_loop from Loop" do
      expect(test_class.private_instance_methods).to include(:fiber_loop)
    end

    it "provides finalize from Completion" do
      expect(test_class.private_instance_methods).to include(:finalize)
    end

    it "provides finalize_error from Completion" do
      expect(test_class.private_instance_methods).to include(:finalize_error)
    end
  end
end
