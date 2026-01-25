require "spec_helper"

RSpec.describe Smolagents::Tools::RubyInterpreterTool::SandboxConfigBuilder do
  subject(:builder) { described_class.new }

  describe "#initialize" do
    it "starts with default values" do
      config = builder.build

      expect(config.timeout_seconds).to eq(30)
      expect(config.max_operations_count).to eq(
        Smolagents::Executors::Executor::DEFAULT_MAX_OPERATIONS
      )
      expect(config.max_output_length_bytes).to eq(
        Smolagents::Executors::Executor::DEFAULT_MAX_OUTPUT_LENGTH
      )
      expect(config.trace_mode_setting).to eq(:line)
      expect(config.authorized_import_list).to be_nil
    end
  end

  describe "#timeout" do
    it "sets the timeout in seconds" do
      builder.timeout(60)
      config = builder.build

      expect(config.timeout_seconds).to eq(60)
    end

    it "returns the value that was set" do
      expect(builder.timeout(45)).to eq(45)
    end
  end

  describe "#max_operations" do
    it "sets the maximum operation count" do
      builder.max_operations(200_000)
      config = builder.build

      expect(config.max_operations_count).to eq(200_000)
    end
  end

  describe "#max_output_length" do
    it "sets the maximum output length in bytes" do
      builder.max_output_length(100_000)
      config = builder.build

      expect(config.max_output_length_bytes).to eq(100_000)
    end
  end

  describe "#trace_mode" do
    it "sets the tracing mode to :call" do
      builder.trace_mode(:call)
      config = builder.build

      expect(config.trace_mode_setting).to eq(:call)
    end

    it "sets the tracing mode to :line" do
      builder.trace_mode(:line)
      config = builder.build

      expect(config.trace_mode_setting).to eq(:line)
    end
  end

  describe "#authorized_imports" do
    it "sets the list of authorized imports" do
      builder.authorized_imports(%w[json time uri])
      config = builder.build

      expect(config.authorized_import_list).to eq(%w[json time uri])
    end

    it "allows an empty array" do
      builder.authorized_imports([])
      config = builder.build

      expect(config.authorized_import_list).to eq([])
    end
  end

  describe "#build" do
    it "returns an immutable SandboxConfig" do
      config = builder.build

      expect(config).to be_a(Smolagents::Tools::RubyInterpreterTool::SandboxConfig)
      expect(config).to be_frozen
    end

    it "captures all configured values" do
      builder.timeout(90)
      builder.max_operations(500_000)
      builder.max_output_length(25_000)
      builder.trace_mode(:call)
      builder.authorized_imports(%w[json])

      config = builder.build

      expect(config.timeout_seconds).to eq(90)
      expect(config.max_operations_count).to eq(500_000)
      expect(config.max_output_length_bytes).to eq(25_000)
      expect(config.trace_mode_setting).to eq(:call)
      expect(config.authorized_import_list).to eq(%w[json])
    end

    it "allows chaining methods" do
      config = described_class.new
                              .tap { |b| b.timeout(15) }
                              .tap { |b| b.max_operations(50_000) }
                              .build

      expect(config.timeout_seconds).to eq(15)
      expect(config.max_operations_count).to eq(50_000)
    end
  end

  describe "DEFAULTS" do
    it "contains expected keys" do
      defaults = described_class::DEFAULTS

      expect(defaults).to include(
        timeout_seconds: 30,
        trace_mode_setting: :line,
        authorized_import_list: nil
      )
    end

    it "is frozen" do
      expect(described_class::DEFAULTS).to be_frozen
    end
  end
end
