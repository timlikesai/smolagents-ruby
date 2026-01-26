require "spec_helper"

RSpec.describe Smolagents::Tools::RubyInterpreterTool::SandboxConfig do
  subject(:config) do
    described_class.new(
      timeout_seconds: 30,
      max_operations_count: 100_000,
      max_output_length_bytes: 50_000,
      trace_mode_setting: :line,
      authorized_import_list: %w[json time]
    )
  end

  describe ".new" do
    it "creates an immutable config" do
      expect(config).to be_frozen
    end

    it "stores all provided values" do
      expect(config.timeout_seconds).to eq(30)
      expect(config.max_operations_count).to eq(100_000)
      expect(config.max_output_length_bytes).to eq(50_000)
      expect(config.trace_mode_setting).to eq(:line)
      expect(config.authorized_import_list).to eq(%w[json time])
    end
  end

  describe "#to_h" do
    it "returns a hash with canonical key names" do
      result = config.to_h

      expect(result).to eq(
        timeout: 30,
        max_operations: 100_000,
        max_output_length: 50_000,
        trace_mode: :line,
        authorized_imports: %w[json time]
      )
    end

    it "maps internal names to canonical names" do
      # timeout_seconds -> timeout
      # max_operations_count -> max_operations
      # max_output_length_bytes -> max_output_length
      # trace_mode_setting -> trace_mode
      # authorized_import_list -> authorized_imports

      result = config.to_h

      expect(result.keys).to contain_exactly(
        :timeout, :max_operations, :max_output_length, :trace_mode, :authorized_imports
      )
    end

    it "handles nil authorized_import_list" do
      config_with_nil = described_class.new(
        timeout_seconds: 30,
        max_operations_count: 100_000,
        max_output_length_bytes: 50_000,
        trace_mode_setting: :line,
        authorized_import_list: nil
      )

      expect(config_with_nil.to_h[:authorized_imports]).to be_nil
    end
  end

  describe "Data.define behavior" do
    it "supports pattern matching" do
      matched = case config
                in { timeout_seconds: 30, trace_mode_setting: :line }
                  true
                else
                  false
                end

      expect(matched).to be true
    end

    it "supports deconstruct_keys" do
      keys = config.deconstruct_keys(%i[timeout_seconds trace_mode_setting])

      expect(keys).to include(timeout_seconds: 30, trace_mode_setting: :line)
    end

    it "is equal to another config with same values" do
      other = described_class.new(
        timeout_seconds: 30,
        max_operations_count: 100_000,
        max_output_length_bytes: 50_000,
        trace_mode_setting: :line,
        authorized_import_list: %w[json time]
      )

      expect(config).to eq(other)
    end

    it "is not equal to config with different values" do
      other = described_class.new(
        timeout_seconds: 60,
        max_operations_count: 100_000,
        max_output_length_bytes: 50_000,
        trace_mode_setting: :line,
        authorized_import_list: %w[json time]
      )

      expect(config).not_to eq(other)
    end
  end
end
