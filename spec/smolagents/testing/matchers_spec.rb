RSpec.describe Smolagents::Testing::Matchers do
  describe "self.included" do
    it "includes AgentMatchers when RSpec is defined" do
      module TestModule
        include Smolagents::Testing::Matchers
      end

      expect(TestModule).to include(Smolagents::Testing::Matchers::AgentMatchers)
    end

    it "includes ToolMatchers" do
      module TestModule
        include Smolagents::Testing::Matchers
      end

      expect(TestModule).to include(Smolagents::Testing::Matchers::ToolMatchers)
    end

    it "includes ModelMatchers" do
      module TestModule
        include Smolagents::Testing::Matchers
      end

      expect(TestModule).to include(Smolagents::Testing::Matchers::ModelMatchers)
    end

    it "includes ResultMatchers" do
      module TestModule
        include Smolagents::Testing::Matchers
      end

      expect(TestModule).to include(Smolagents::Testing::Matchers::ResultMatchers)
    end
  end

  describe "integration with RSpec" do
    let(:rspec_context) do
      Class.new do
        include RSpec::Matchers
        include Smolagents::Testing::Matchers
      end.new
    end

    it "makes matchers available in RSpec examples" do
      # Verify that including the module in an RSpec context works
      expect(rspec_context).to respond_to(:include)
      expect(described_class).to be_a(Module)
    end
  end

  describe "matcher composition" do
    it "has all expected matcher modules available" do
      expect(defined?(Smolagents::Testing::Matchers::AgentMatchers)).not_to be_nil
      expect(defined?(Smolagents::Testing::Matchers::ToolMatchers)).not_to be_nil
      expect(defined?(Smolagents::Testing::Matchers::ModelMatchers)).not_to be_nil
      expect(defined?(Smolagents::Testing::Matchers::ResultMatchers)).not_to be_nil
      expect(defined?(Smolagents::Testing::Matchers::DSL)).not_to be_nil
    end
  end
end
