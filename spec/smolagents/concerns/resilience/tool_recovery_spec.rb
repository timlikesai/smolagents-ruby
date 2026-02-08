require "spec_helper"

# rubocop:disable RSpec/VerifiedDoubleReference -- Tool is not a constant in spec context
RSpec.describe Smolagents::Concerns::Resilience::ToolRecovery do
  let(:recovery_action) { Smolagents::Types::RecoveryAction }
  let(:recovery_config) { Smolagents::Types::ToolRecoveryConfig }

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Resilience::ToolRecovery

      attr_accessor :tools

      def initialize(config: nil)
        initialize_tool_recovery(config:)
        @tools = {}
      end

      # Make private methods accessible for testing
      public :execute_with_recovery, :select_recovery_action
    end
  end

  let(:executor) { test_class.new }

  let(:successful_tool) do
    tool = instance_double("Tool", name: "search")
    allow(tool).to receive(:execute).and_return("result")
    tool
  end

  let(:failing_tool) do
    tool = instance_double("Tool", name: "flaky")
    call_count = 0
    allow(tool).to receive(:execute) do
      call_count += 1
      raise "transient error" if call_count < 3

      "recovered"
    end
    tool
  end

  describe "#initialize_tool_recovery" do
    it "sets default config" do
      expect(executor.tool_recovery_config).to be_a(recovery_config)
      expect(executor.tool_recovery_config.enabled).to be true
    end

    it "accepts custom config" do
      custom = recovery_config.disabled
      executor = test_class.new(config: custom)
      expect(executor.tool_recovery_config.enabled).to be false
    end
  end

  describe "#execute_with_recovery" do
    context "with successful execution" do
      it "returns success result on first attempt" do
        result = executor.execute_with_recovery(successful_tool, { query: "test" })

        expect(result).to be_success
        expect(result.attempts).to eq(1)
        expect(result.final_result).to eq("result")
      end

      it "does not emit recovery_succeeded on first attempt" do
        events = []
        allow(executor).to receive(:emit) { |name, **| events << name }

        executor.execute_with_recovery(successful_tool, { query: "test" })

        expect(events).not_to include(:tool_recovery_succeeded)
      end
    end

    context "with transient failure then success" do
      it "retries and succeeds" do
        result = executor.execute_with_recovery(failing_tool, { query: "test" })

        expect(result).to be_success
        expect(result.attempts).to eq(3)
        expect(result.final_result).to eq("recovered")
      end

      it "emits recovery_attempted events" do
        events = []
        allow(executor).to receive(:emit) { |name, **kwargs| events << [name, kwargs] }

        executor.execute_with_recovery(failing_tool, { query: "test" })

        # rubocop:disable Style/HashSlice -- events is an Array, not a Hash
        attempt_events = events.select { |name, _| name == :tool_recovery_attempted }
        # rubocop:enable Style/HashSlice
        expect(attempt_events.length).to eq(2) # attempts 1 and 2 failed
      end

      it "emits recovery_succeeded on recovery" do
        events = []
        allow(executor).to receive(:emit) { |name, **kwargs| events << [name, kwargs] }

        executor.execute_with_recovery(failing_tool, { query: "test" })

        # rubocop:disable Style/HashSlice -- events is an Array, not a Hash
        success_events = events.select { |name, _| name == :tool_recovery_succeeded }
        # rubocop:enable Style/HashSlice
        expect(success_events.length).to eq(1)
        expect(success_events.first[1][:attempts]).to eq(3)
      end
    end

    context "with max attempts exhausted" do
      let(:always_failing_tool) do
        tool = instance_double("Tool", name: "broken")
        allow(tool).to receive(:execute).and_raise(RuntimeError, "permanent error")
        tool
      end

      it "returns failure result after max attempts" do
        result = executor.execute_with_recovery(always_failing_tool, { query: "test" })

        expect(result).to be_failed
        expect(result.attempts).to eq(3)
        expect(result.original_error.message).to eq("permanent error")
      end

      it "sets gave_up? to true" do
        result = executor.execute_with_recovery(always_failing_tool, {})
        expect(result.gave_up?).to be true
      end
    end

    context "with disabled recovery" do
      let(:disabled_executor) { test_class.new(config: recovery_config.disabled) }

      it "returns success without recovery logic" do
        result = disabled_executor.execute_with_recovery(successful_tool, {})

        expect(result).to be_success
        expect(result.attempts).to eq(1)
      end

      it "returns failure on first error" do
        failing = instance_double("Tool", name: "fail")
        allow(failing).to receive(:execute).and_raise(RuntimeError, "error")

        result = disabled_executor.execute_with_recovery(failing, {})

        expect(result).to be_failed
        expect(result.attempts).to eq(1)
      end
    end

    context "with ArgumentError (reformat action)" do
      let(:format_sensitive_tool) do
        tool = instance_double("Tool", name: "parser")
        call_count = 0
        allow(tool).to receive(:execute) do |args|
          call_count += 1
          raise ArgumentError, "bad format" if call_count == 1

          args[:input].to_s
        end
        tool
      end

      it "reformats arguments and retries" do
        result = executor.execute_with_recovery(format_sensitive_tool, { input: "  test  " })

        expect(result).to be_success
        expect(result.attempts).to eq(2)
      end
    end
  end

  describe "#select_recovery_action" do
    it "returns TERMINATE when max attempts reached" do
      action = executor.select_recovery_action(successful_tool, RuntimeError.new("x"), 3)
      expect(action).to eq(recovery_action::TERMINATE)
    end

    it "returns REFORMAT for ArgumentError when allowed" do
      action = executor.select_recovery_action(successful_tool, ArgumentError.new("bad"), 1)
      expect(action).to eq(recovery_action::REFORMAT)
    end

    it "returns RETRY for Faraday::ServerError when allowed" do
      error = Faraday::ServerError.new(status: 500)
      action = executor.select_recovery_action(successful_tool, error, 1)
      expect(action).to eq(recovery_action::RETRY)
    end

    it "returns RETRY for Faraday::TimeoutError when allowed" do
      error = Faraday::TimeoutError.new("timeout")
      action = executor.select_recovery_action(successful_tool, error, 1)
      expect(action).to eq(recovery_action::RETRY)
    end

    it "returns RETRY for unknown errors when retry allowed" do
      action = executor.select_recovery_action(successful_tool, RuntimeError.new("x"), 1)
      expect(action).to eq(recovery_action::RETRY)
    end

    context "with switch enabled and fallback configured" do
      let(:switch_config) do
        recovery_config.new(
          enabled: true, max_attempts: 3, allow_retry: false,
          allow_reformat: false, allow_switch: true,
          fallback_tools: { "search" => "web_search" }
        )
      end

      let(:switch_executor) { test_class.new(config: switch_config) }

      it "returns SWITCH when fallback exists" do
        tool = instance_double("Tool", name: "search")
        action = switch_executor.select_recovery_action(tool, RuntimeError.new("x"), 1)
        expect(action).to eq(recovery_action::SWITCH)
      end

      it "returns TERMINATE when no fallback exists" do
        tool = instance_double("Tool", name: "unknown")
        action = switch_executor.select_recovery_action(tool, RuntimeError.new("x"), 1)
        expect(action).to eq(recovery_action::TERMINATE)
      end
    end
  end

  describe "fallback tool execution" do
    let(:fallback_config) do
      recovery_config.new(
        enabled: true, max_attempts: 3, allow_retry: false,
        allow_reformat: false, allow_switch: true,
        fallback_tools: { "primary" => "backup" }
      )
    end

    let(:fallback_executor) { test_class.new(config: fallback_config) }

    let(:primary_tool) do
      tool = instance_double("Tool", name: "primary")
      allow(tool).to receive(:execute).and_raise(RuntimeError, "primary failed")
      tool
    end

    let(:backup_tool) do
      tool = instance_double("Tool", name: "backup")
      allow(tool).to receive(:execute).and_return("backup result")
      tool
    end

    it "switches to fallback tool on failure" do
      fallback_executor.tools = { "backup" => backup_tool }

      result = fallback_executor.execute_with_recovery(primary_tool, { query: "test" })

      expect(result).to be_success
      expect(result.final_result).to eq("backup result")
      expect(result.action).to eq(recovery_action::SWITCH)
    end

    it "fails when fallback tool also fails" do
      failing_backup = instance_double("Tool", name: "backup")
      allow(failing_backup).to receive(:execute).and_raise(RuntimeError, "backup also failed")
      fallback_executor.tools = { "backup" => failing_backup }

      result = fallback_executor.execute_with_recovery(primary_tool, { query: "test" })

      expect(result).to be_failed
      expect(result.reason).to eq("Fallback also failed")
    end

    it "fails when no fallback tool found" do
      fallback_executor.tools = {} # No backup tool registered

      result = fallback_executor.execute_with_recovery(primary_tool, { query: "test" })

      expect(result).to be_failed
      expect(result.reason).to eq("No fallback tool")
    end
  end

  describe "event emission" do
    it "emits tool_recovery_attempted with correct data" do
      failing = instance_double("Tool", name: "failing")
      allow(failing).to receive(:execute).and_raise(RuntimeError, "test error")

      events = []
      allow(executor).to receive(:emit) do |name, **kwargs|
        events << { name:, **kwargs }
      end

      executor.execute_with_recovery(failing, {})

      event = events.find { |e| e[:name] == :tool_recovery_attempted }
      expect(event).to include(
        tool_name: "failing",
        error_class: "RuntimeError",
        error_message: "test error"
      )
    end

    it "emits tool_recovery_succeeded with attempts count" do
      events = []
      allow(executor).to receive(:emit) do |name, **kwargs|
        events << { name:, **kwargs }
      end

      executor.execute_with_recovery(failing_tool, {})

      event = events.find { |e| e[:name] == :tool_recovery_succeeded }
      expect(event).to include(
        tool_name: "flaky",
        attempts: 3
      )
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubleReference
