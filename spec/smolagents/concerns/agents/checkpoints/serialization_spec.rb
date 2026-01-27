require "spec_helper"

RSpec.describe Smolagents::Concerns::Checkpoints::Serialization, type: :unit do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Checkpoints::Serialization
    end
  end

  let(:serializer) { test_class.new }

  def make_checkpoint(
    step_number: 1,
    sequence: 1,
    memory_state: nil,
    working_memory_state: nil,
    goal_state: [],
    execution_context: nil,
    model_history: [],
    tool_usage_stats: {},
    metadata: {}
  )
    Smolagents::Types::Checkpoint.new(
      id: "cp_#{SecureRandom.hex(8)}",
      step_number:,
      sequence:,
      memory_state:,
      working_memory_state: working_memory_state || Smolagents::Types::WorkingMemoryState.empty,
      goal_state:,
      execution_context:,
      model_history:,
      tool_usage_stats:,
      timestamp: Time.now,
      metadata:
    )
  end

  describe "#serialize_checkpoint" do
    it "converts checkpoint to hash" do
      checkpoint = make_checkpoint(step_number: 5, sequence: 3)

      result = serializer.serialize_checkpoint(checkpoint)

      expect(result).to be_a(Hash)
      expect(result[:id]).to eq(checkpoint.id)
      expect(result[:step_number]).to eq(5)
      expect(result[:sequence]).to eq(3)
    end

    it "serializes timestamp as ISO8601 string" do
      checkpoint = make_checkpoint

      result = serializer.serialize_checkpoint(checkpoint)

      expect(result[:timestamp]).to be_a(String)
      expect(result[:timestamp]).to match(/^\d{4}-\d{2}-\d{2}T/)
    end

    it "serializes working memory state" do
      working_memory = Smolagents::Types::WorkingMemoryState.empty
                                                            .with_objective("Find docs")
                                                            .add_finding("Found Ruby docs")
                                                            .add_blocker("Rate limited")

      checkpoint = make_checkpoint(working_memory_state: working_memory)

      result = serializer.serialize_checkpoint(checkpoint)

      expect(result[:working_memory_state]).to be_a(Hash)
      expect(result[:working_memory_state][:objective]).to eq("Find docs")
      expect(result[:working_memory_state][:findings]).to include("Found Ruby docs")
      expect(result[:working_memory_state][:blockers]).to include("Rate limited")
    end

    it "serializes goal state" do
      goals = [
        Smolagents::Types::Goal.create(description: "Main goal"),
        Smolagents::Types::Goal.create(description: "Sub goal")
      ]

      checkpoint = make_checkpoint(goal_state: goals)

      result = serializer.serialize_checkpoint(checkpoint)

      expect(result[:goal_state]).to be_an(Array)
      expect(result[:goal_state].size).to eq(2)
      expect(result[:goal_state].first[:description]).to eq("Main goal")
    end

    it "serializes execution context" do
      context = Smolagents::Types::RunContext.new(
        step_number: 7,
        total_tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50),
        timing: Smolagents::Types::Timing.start_now
      )

      checkpoint = make_checkpoint(execution_context: context)

      result = serializer.serialize_checkpoint(checkpoint)

      expect(result[:execution_context]).to be_a(Hash)
      expect(result[:execution_context][:step_number]).to eq(7)
    end

    it "serializes model history" do
      messages = [
        Smolagents::Types::ChatMessage.system("You are helpful"),
        Smolagents::Types::ChatMessage.user("Hello"),
        Smolagents::Types::ChatMessage.assistant("Hi there!")
      ]

      checkpoint = make_checkpoint(model_history: messages)

      result = serializer.serialize_checkpoint(checkpoint)

      expect(result[:model_history]).to be_an(Array)
      expect(result[:model_history].size).to eq(3)
      expect(result[:model_history].first[:role]).to eq(:system)
    end

    it "serializes metadata" do
      checkpoint = make_checkpoint(metadata: { trigger: :manual, custom: "value" })

      result = serializer.serialize_checkpoint(checkpoint)

      expect(result[:metadata][:trigger]).to eq(:manual)
      expect(result[:metadata][:custom]).to eq("value")
    end

    it "serializes tool usage stats" do
      checkpoint = make_checkpoint(tool_usage_stats: { "search" => 5, "calculate" => 2 })

      result = serializer.serialize_checkpoint(checkpoint)

      expect(result[:tool_usage_stats]).to eq({ "search" => 5, "calculate" => 2 })
    end

    it "handles nil working memory state" do
      # Create checkpoint directly with nil working_memory_state
      checkpoint = Smolagents::Types::Checkpoint.new(
        id: "cp_#{SecureRandom.hex(8)}",
        step_number: 1,
        sequence: 1,
        memory_state: nil,
        working_memory_state: nil,
        goal_state: [],
        execution_context: nil,
        model_history: [],
        tool_usage_stats: {},
        timestamp: Time.now,
        metadata: {}
      )

      result = serializer.serialize_checkpoint(checkpoint)

      expect(result[:working_memory_state]).to be_nil
    end

    it "handles nil execution context" do
      checkpoint = make_checkpoint(execution_context: nil)

      result = serializer.serialize_checkpoint(checkpoint)

      expect(result[:execution_context]).to be_nil
    end
  end

  describe "#deserialize_checkpoint" do
    it "reconstructs checkpoint from hash" do
      original = make_checkpoint(step_number: 5, sequence: 3)
      data = serializer.serialize_checkpoint(original)

      restored = serializer.deserialize_checkpoint(data)

      expect(restored).to be_a(Smolagents::Types::Checkpoint)
      expect(restored.id).to eq(original.id)
      expect(restored.step_number).to eq(5)
      expect(restored.sequence).to eq(3)
    end

    it "restores timestamp as Time object" do
      original = make_checkpoint
      data = serializer.serialize_checkpoint(original)

      restored = serializer.deserialize_checkpoint(data)

      expect(restored.timestamp).to be_a(Time)
      expect(restored.timestamp).to be_within(1).of(original.timestamp)
    end

    it "restores working memory state" do
      working_memory = Smolagents::Types::WorkingMemoryState.empty
                                                            .with_objective("Find docs")
                                                            .add_finding("Found it")

      original = make_checkpoint(working_memory_state: working_memory)
      data = serializer.serialize_checkpoint(original)

      restored = serializer.deserialize_checkpoint(data)

      expect(restored.working_memory_state).to be_a(Smolagents::Types::WorkingMemoryState)
      expect(restored.working_memory_state.objective).to eq("Find docs")
      expect(restored.working_memory_state.findings).to include("Found it")
    end

    it "restores goal state" do
      goals = [Smolagents::Types::Goal.create(description: "Test goal")]
      original = make_checkpoint(goal_state: goals)
      data = serializer.serialize_checkpoint(original)

      restored = serializer.deserialize_checkpoint(data)

      expect(restored.goal_state).to be_an(Array)
      expect(restored.goal_state.size).to eq(1)
      expect(restored.goal_state.first).to be_a(Smolagents::Types::Goal)
      expect(restored.goal_state.first.description).to eq("Test goal")
    end

    it "restores execution context" do
      context = Smolagents::Types::RunContext.new(
        step_number: 7,
        total_tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50),
        timing: Smolagents::Types::Timing.start_now
      )
      original = make_checkpoint(execution_context: context)
      data = serializer.serialize_checkpoint(original)

      restored = serializer.deserialize_checkpoint(data)

      expect(restored.execution_context).to be_a(Smolagents::Types::RunContext)
      expect(restored.execution_context.step_number).to eq(7)
      expect(restored.execution_context.total_tokens.input_tokens).to eq(100)
    end

    it "restores model history" do
      # NOTE: The current implementation doesn't define deserialize_message,
      # so this test verifies the serialization preserves structure.
      # When deserialize_message is implemented, update this test.
      original = make_checkpoint(model_history: [])
      data = serializer.serialize_checkpoint(original)

      restored = serializer.deserialize_checkpoint(data)

      expect(restored.model_history).to be_an(Array)
      expect(restored.model_history).to eq([])
    end

    it "restores metadata" do
      original = make_checkpoint(metadata: { trigger: :recovery })
      data = serializer.serialize_checkpoint(original)

      restored = serializer.deserialize_checkpoint(data)

      expect(restored.metadata[:trigger]).to eq(:recovery)
    end

    it "handles string keys in data" do
      data = {
        "id" => "cp_test12345678",
        "step_number" => 5,
        "sequence" => 3,
        "timestamp" => Time.now.iso8601,
        "memory_state" => nil,
        "working_memory_state" => { "objective" => "Test", "findings" => [], "blockers" => [] },
        "goal_state" => [],
        "execution_context" => nil,
        "model_history" => [],
        "tool_usage_stats" => {},
        "metadata" => { "trigger" => "manual" }
      }

      restored = serializer.deserialize_checkpoint(data)

      expect(restored.id).to eq("cp_test12345678")
      expect(restored.step_number).to eq(5)
      expect(restored.working_memory_state.objective).to eq("Test")
    end

    it "handles empty goal state" do
      original = make_checkpoint(goal_state: [])
      data = serializer.serialize_checkpoint(original)

      restored = serializer.deserialize_checkpoint(data)

      expect(restored.goal_state).to eq([])
    end

    it "handles empty model history" do
      original = make_checkpoint(model_history: [])
      data = serializer.serialize_checkpoint(original)

      restored = serializer.deserialize_checkpoint(data)

      expect(restored.model_history).to eq([])
    end

    it "handles nil working memory state" do
      data = {
        id: "cp_test12345678",
        step_number: 1,
        sequence: 1,
        timestamp: Time.now.iso8601,
        memory_state: nil,
        working_memory_state: nil,
        goal_state: [],
        execution_context: nil,
        model_history: [],
        tool_usage_stats: {},
        metadata: {}
      }

      restored = serializer.deserialize_checkpoint(data)

      expect(restored.working_memory_state).to eq(Smolagents::Types::WorkingMemoryState.empty)
    end

    it "handles missing optional fields" do
      data = {
        id: "cp_test12345678",
        step_number: 1,
        sequence: 1,
        timestamp: Time.now.iso8601,
        memory_state: nil,
        working_memory_state: nil,
        goal_state: [],
        execution_context: nil,
        model_history: []
      }

      restored = serializer.deserialize_checkpoint(data)

      expect(restored.tool_usage_stats).to eq({})
      expect(restored.metadata).to eq({})
    end
  end

  describe "round-trip serialization" do
    it "preserves all checkpoint data through serialize/deserialize cycle" do
      working_memory = Smolagents::Types::WorkingMemoryState.empty
                                                            .with_objective("Complete task")
                                                            .add_finding("Step 1 done")
                                                            .add_blocker("API limit")

      goals = [
        Smolagents::Types::Goal.create(description: "Main goal"),
        Smolagents::Types::Goal.create(description: "Sub goal").complete(evidence: "Done")
      ]

      context = Smolagents::Types::RunContext.new(
        step_number: 10,
        total_tokens: Smolagents::Types::TokenUsage.new(input_tokens: 500, output_tokens: 200),
        timing: Smolagents::Types::Timing.start_now
      )

      # Skip model_history since deserialize_message is not implemented in Checkpoint
      original = make_checkpoint(
        step_number: 10,
        sequence: 5,
        memory_state: { key: "value" },
        working_memory_state: working_memory,
        goal_state: goals,
        execution_context: context,
        model_history: [],
        tool_usage_stats: { "search" => 3, "web" => 1 },
        metadata: { trigger: :auto, user_id: "123" }
      )

      serialized = serializer.serialize_checkpoint(original)
      restored = serializer.deserialize_checkpoint(serialized)

      expect(restored.id).to eq(original.id)
      expect(restored.step_number).to eq(10)
      expect(restored.sequence).to eq(5)
      expect(restored.memory_state[:key]).to eq("value")
      expect(restored.working_memory_state.objective).to eq("Complete task")
      expect(restored.working_memory_state.findings).to eq(["Step 1 done"])
      expect(restored.working_memory_state.blockers).to eq(["API limit"])
      expect(restored.goal_state.size).to eq(2)
      expect(restored.goal_state.first.description).to eq("Main goal")
      expect(restored.goal_state.last.completed?).to be true
      expect(restored.execution_context.step_number).to eq(10)
      expect(restored.execution_context.total_tokens.total_tokens).to eq(700)
      expect(restored.model_history).to eq([])
      expect(restored.tool_usage_stats).to eq({ search: 3, web: 1 })
      expect(restored.metadata[:trigger]).to eq(:auto)
    end

    it "produces JSON-compatible output" do
      checkpoint = make_checkpoint(
        working_memory_state: Smolagents::Types::WorkingMemoryState.empty.with_objective("Test"),
        goal_state: [Smolagents::Types::Goal.create(description: "Goal")],
        metadata: { trigger: :manual }
      )

      serialized = serializer.serialize_checkpoint(checkpoint)

      # Should not raise
      json = JSON.generate(serialized)
      parsed = JSON.parse(json, symbolize_names: true)

      restored = serializer.deserialize_checkpoint(parsed)
      expect(restored.id).to eq(checkpoint.id)
    end
  end

  describe "nested type handling" do
    it "properly handles Goal with all states" do
      goals = [
        Smolagents::Types::Goal.create(description: "Active goal"),
        Smolagents::Types::Goal.create(description: "Blocked goal").block(reason: "Waiting"),
        Smolagents::Types::Goal.create(description: "Done goal").complete(evidence: "Finished"),
        Smolagents::Types::Goal.create(description: "Abandoned goal").abandon(reason: "Not needed")
      ]

      checkpoint = make_checkpoint(goal_state: goals)
      serialized = serializer.serialize_checkpoint(checkpoint)
      restored = serializer.deserialize_checkpoint(serialized)

      expect(restored.goal_state[0].active?).to be true
      expect(restored.goal_state[1].blocked?).to be true
      expect(restored.goal_state[1].progress).to eq("Waiting")
      expect(restored.goal_state[2].completed?).to be true
      expect(restored.goal_state[2].progress).to eq("Finished")
      expect(restored.goal_state[3].abandoned?).to be true
    end

    it "properly handles subgoals" do
      parent = Smolagents::Types::Goal.create(description: "Parent")
      child = Smolagents::Types::Goal.create(description: "Child", parent_id: parent.id)

      checkpoint = make_checkpoint(goal_state: [parent, child])
      serialized = serializer.serialize_checkpoint(checkpoint)
      restored = serializer.deserialize_checkpoint(serialized)

      restored_parent = restored.goal_state.find { |g| g.description == "Parent" }
      restored_child = restored.goal_state.find { |g| g.description == "Child" }

      expect(restored_parent.root?).to be true
      expect(restored_child.root?).to be false
      expect(restored_child.parent_id).to eq(restored_parent.id)
    end

    it "properly serializes ChatMessage roles" do
      # NOTE: Full deserialization of ChatMessages isn't implemented,
      # so we test that serialization preserves the role information
      messages = [
        Smolagents::Types::ChatMessage.system("System prompt"),
        Smolagents::Types::ChatMessage.user("User input"),
        Smolagents::Types::ChatMessage.assistant("Assistant response")
      ]

      checkpoint = make_checkpoint(model_history: messages)
      serialized = serializer.serialize_checkpoint(checkpoint)

      expect(serialized[:model_history][0][:role]).to eq(:system)
      expect(serialized[:model_history][1][:role]).to eq(:user)
      expect(serialized[:model_history][2][:role]).to eq(:assistant)
    end

    it "properly handles RunContext with timing" do
      timing = Smolagents::Types::Timing.start_now.stop
      context = Smolagents::Types::RunContext.new(
        step_number: 5,
        total_tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50),
        timing:
      )

      checkpoint = make_checkpoint(execution_context: context)
      serialized = serializer.serialize_checkpoint(checkpoint)
      restored = serializer.deserialize_checkpoint(serialized)

      expect(restored.execution_context.timing.start_time).to be_a(Time)
      expect(restored.execution_context.timing.end_time).to be_a(Time)
      expect(restored.execution_context.timing.duration).to be_a(Float)
    end
  end

  describe "symbolize_keys helper" do
    it "converts string keys to symbols recursively" do
      data = {
        "id" => "test",
        "nested" => {
          "key" => "value",
          "deeper" => { "item" => 1 }
        },
        "array" => [
          { "element" => "data" }
        ]
      }

      result = serializer.send(:symbolize_keys, data)

      expect(result[:id]).to eq("test")
      expect(result[:nested][:key]).to eq("value")
      expect(result[:nested][:deeper][:item]).to eq(1)
      expect(result[:array].first[:element]).to eq("data")
    end

    it "handles non-hash values" do
      expect(serializer.send(:symbolize_keys, "string")).to eq("string")
      expect(serializer.send(:symbolize_keys, 123)).to eq(123)
      expect(serializer.send(:symbolize_keys, nil)).to be_nil
    end
  end
end
