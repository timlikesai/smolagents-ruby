require "spec_helper"

RSpec.describe Smolagents::Concerns::Compositions do
  describe "FullFeatured" do
    it "includes all expected concerns" do
      test_class = Class.new do
        include Smolagents::Concerns::Compositions::FullFeatured
      end

      expect(test_class.included_modules).to include(Smolagents::Concerns::ReActLoop)
      expect(test_class.included_modules).to include(Smolagents::Concerns::Planning)
      expect(test_class.included_modules).to include(Smolagents::Concerns::CodeExecution)
    end
  end

  describe "MinimalCode" do
    it "includes ReActLoop and CodeExecution" do
      test_class = Class.new do
        include Smolagents::Concerns::Compositions::MinimalCode
      end

      expect(test_class.included_modules).to include(Smolagents::Concerns::ReActLoop)
      expect(test_class.included_modules).to include(Smolagents::Concerns::CodeExecution)
    end
  end

  describe "WithRefinement" do
    it "includes SelfRefine concern" do
      test_class = Class.new do
        include Smolagents::Concerns::Compositions::WithRefinement
      end

      expect(test_class.included_modules).to include(Smolagents::Concerns::SelfRefine)
    end
  end

  describe "WithMemory" do
    it "includes ReflectionMemory concern" do
      test_class = Class.new do
        include Smolagents::Concerns::Compositions::WithMemory
      end

      expect(test_class.included_modules).to include(Smolagents::Concerns::ReflectionMemory)
    end
  end

  describe "Interactive" do
    it "includes Control and Planning concerns" do
      test_class = Class.new do
        include Smolagents::Concerns::Compositions::Interactive
      end

      expect(test_class.included_modules).to include(Smolagents::Concerns::ReActLoop::Control)
      expect(test_class.included_modules).to include(Smolagents::Concerns::Planning)
    end
  end
end
