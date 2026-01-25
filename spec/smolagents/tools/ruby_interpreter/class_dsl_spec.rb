require "spec_helper"

RSpec.describe Smolagents::Tools::RubyInterpreterTool::ClassDsl do
  let(:base_class) do
    Class.new(Smolagents::Tools::RubyInterpreterTool)
  end

  describe ".sandbox" do
    it "accepts a configuration block" do
      base_class.sandbox do |config|
        config.timeout(60)
        config.max_operations(200_000)
      end

      config = base_class.sandbox_config
      expect(config.timeout_seconds).to eq(60)
      expect(config.max_operations_count).to eq(200_000)
    end

    it "returns a SandboxConfig" do
      result = base_class.sandbox { |c| c.timeout(45) }

      expect(result).to be_a(Smolagents::Tools::RubyInterpreterTool::SandboxConfig)
    end

    it "works without a block" do
      base_class.sandbox

      expect(base_class.sandbox_config).to be_a(
        Smolagents::Tools::RubyInterpreterTool::SandboxConfig
      )
    end
  end

  describe ".sandbox_config" do
    it "returns default config when not configured" do
      config = base_class.sandbox_config

      expect(config).to be_a(Smolagents::Tools::RubyInterpreterTool::SandboxConfig)
      expect(config.timeout_seconds).to eq(30)
    end

    it "inherits configuration from parent class" do
      base_class.sandbox { |c| c.timeout(120) }

      subclass = Class.new(base_class)

      expect(subclass.sandbox_config.timeout_seconds).to eq(120)
    end

    it "allows subclass to override parent configuration" do
      base_class.sandbox { |c| c.timeout(120) }

      subclass = Class.new(base_class)
      subclass.sandbox { |c| c.timeout(30) }

      expect(base_class.sandbox_config.timeout_seconds).to eq(120)
      expect(subclass.sandbox_config.timeout_seconds).to eq(30)
    end

    it "returns fresh default when neither class nor parent has config" do
      fresh_class = Class.new(Smolagents::Tools::RubyInterpreterTool)
      config = fresh_class.sandbox_config

      expect(config.timeout_seconds).to eq(30)
      expect(config.max_operations_count).to eq(
        Smolagents::Executors::Executor::DEFAULT_MAX_OPERATIONS
      )
    end
  end
end
