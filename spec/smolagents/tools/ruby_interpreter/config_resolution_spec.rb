require "spec_helper"

RSpec.describe Smolagents::Tools::RubyInterpreterTool::ConfigResolution do
  let(:default_imports) { Smolagents::Config::Configuration::DEFAULT_AUTHORIZED_IMPORTS }

  describe "#resolve_config" do
    it "uses defaults when no arguments provided" do
      tool = Smolagents::RubyInterpreterTool.new

      expect(tool.timeout).to eq(30)
      expect(tool.authorized_imports).to eq(default_imports)
    end

    it "accepts explicit timeout argument" do
      tool = Smolagents::RubyInterpreterTool.new(timeout: 60)

      expect(tool.timeout).to eq(60)
    end

    it "accepts explicit authorized_imports argument" do
      tool = Smolagents::RubyInterpreterTool.new(authorized_imports: %w[json])

      expect(tool.authorized_imports).to eq(%w[json])
    end

    context "with class-level sandbox configuration" do
      let(:custom_class) do
        Class.new(Smolagents::RubyInterpreterTool) do
          self.tool_name = "custom_ruby"
          self.description = "Custom Ruby interpreter"
          sandbox do |config|
            config.timeout(120)
            config.authorized_imports(%w[time date])
          end
        end
      end

      it "uses class config when no arguments provided" do
        tool = custom_class.new

        expect(tool.timeout).to eq(120)
        expect(tool.authorized_imports).to eq(%w[time date])
      end

      it "prefers explicit arguments over class config" do
        tool = custom_class.new(timeout: 15, authorized_imports: %w[json])

        expect(tool.timeout).to eq(15)
        expect(tool.authorized_imports).to eq(%w[json])
      end

      it "merges class config with defaults for unset values" do
        partial_class = Class.new(Smolagents::RubyInterpreterTool) do
          self.tool_name = "partial_ruby"
          self.description = "Partial Ruby interpreter"
          sandbox { |config| config.timeout(45) }
        end

        tool = partial_class.new

        expect(tool.timeout).to eq(45)
        expect(tool.authorized_imports).to eq(default_imports)
      end
    end

    context "priority ordering" do
      let(:custom_class) do
        Class.new(Smolagents::RubyInterpreterTool) do
          self.tool_name = "priority_ruby"
          self.description = "Priority Ruby interpreter"
          sandbox { |config| config.timeout(100) }
        end
      end

      it "follows priority: explicit > class > defaults" do
        # Default from CONFIG_DEFAULTS is 30
        # Class config sets 100
        # Explicit argument is 5

        tool_default = Smolagents::RubyInterpreterTool.new
        tool_class = custom_class.new
        tool_explicit = custom_class.new(timeout: 5)

        expect(tool_default.timeout).to eq(30)
        expect(tool_class.timeout).to eq(100)
        expect(tool_explicit.timeout).to eq(5)
      end
    end
  end

  describe "CONFIG_DEFAULTS" do
    let(:defaults) do
      Smolagents::Tools::RubyInterpreterTool::ConfigResolution::CONFIG_DEFAULTS
    end

    it "includes expected keys" do
      expect(defaults).to include(
        :timeout,
        :max_operations,
        :max_output_length,
        :trace_mode,
        :authorized_imports
      )
    end

    it "has sensible default values" do
      expect(defaults[:timeout]).to eq(30)
      expect(defaults[:trace_mode]).to eq(:line)
      expect(defaults[:authorized_imports]).to eq(default_imports)
    end

    it "is frozen" do
      expect(defaults).to be_frozen
    end
  end
end
