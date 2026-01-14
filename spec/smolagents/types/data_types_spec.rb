RSpec.describe Smolagents::TokenUsage do
  describe ".zero" do
    it "creates usage with zero tokens" do
      usage = described_class.zero
      expect(usage.input_tokens).to eq(0)
      expect(usage.output_tokens).to eq(0)
    end

    it "is immutable" do
      usage = described_class.zero
      expect(usage).to be_frozen
    end
  end

  describe "#+" do
    it "adds token counts" do
      a = described_class.new(input_tokens: 100, output_tokens: 50)
      b = described_class.new(input_tokens: 200, output_tokens: 75)

      result = a + b

      expect(result.input_tokens).to eq(300)
      expect(result.output_tokens).to eq(125)
    end

    it "works with zero" do
      usage = described_class.new(input_tokens: 100, output_tokens: 50)
      result = described_class.zero + usage

      expect(result).to eq(usage)
    end

    it "adds large token counts" do
      a = described_class.new(input_tokens: 1_000_000, output_tokens: 500_000)
      b = described_class.new(input_tokens: 2_000_000, output_tokens: 1_000_000)

      result = a + b

      expect(result.input_tokens).to eq(3_000_000)
      expect(result.output_tokens).to eq(1_500_000)
    end

    it "raises error if other is not TokenUsage" do
      usage = described_class.new(input_tokens: 100, output_tokens: 50)
      # rubocop:disable Style/StringConcatenation
      expect { usage + "not a usage" }.to raise_error(NoMethodError)
      # rubocop:enable Style/StringConcatenation
    end

    it "returns new object, not mutating original" do
      a = described_class.new(input_tokens: 100, output_tokens: 50)
      b = described_class.new(input_tokens: 200, output_tokens: 75)
      original_a = a

      result = a + b

      expect(a).to equal(original_a)
      expect(a.input_tokens).to eq(100)
      expect(result).not_to equal(a)
    end
  end

  describe "#total_tokens" do
    it "returns sum of input and output tokens" do
      usage = described_class.new(input_tokens: 100, output_tokens: 50)
      expect(usage.total_tokens).to eq(150)
    end

    it "handles zero tokens" do
      usage = described_class.zero
      expect(usage.total_tokens).to eq(0)
    end

    it "handles large token counts" do
      usage = described_class.new(input_tokens: 10_000_000, output_tokens: 5_000_000)
      expect(usage.total_tokens).to eq(15_000_000)
    end

    it "works with asymmetric token distributions" do
      usage = described_class.new(input_tokens: 1, output_tokens: 999)
      expect(usage.total_tokens).to eq(1000)
    end
  end

  describe "#to_h" do
    it "returns hash with total_tokens included" do
      usage = described_class.new(input_tokens: 100, output_tokens: 50)
      expect(usage.to_h).to eq({
                                 input_tokens: 100,
                                 output_tokens: 50,
                                 total_tokens: 150
                               })
    end

    it "has correct keys" do
      usage = described_class.new(input_tokens: 100, output_tokens: 50)
      hash = usage.to_h
      expect(hash.keys).to contain_exactly(:input_tokens, :output_tokens, :total_tokens)
    end

    it "preserves zero values" do
      usage = described_class.zero
      hash = usage.to_h
      expect(hash).to eq({
                           input_tokens: 0,
                           output_tokens: 0,
                           total_tokens: 0
                         })
    end
  end

  describe "pattern matching" do
    it "matches on input_tokens" do
      usage = described_class.new(input_tokens: 100, output_tokens: 50)

      result = case usage
               in input_tokens: 100
                 "matched"
               else
                 "not matched"
               end

      expect(result).to eq("matched")
    end

    it "matches on both tokens" do
      usage = described_class.new(input_tokens: 100, output_tokens: 50)

      result = case usage
               in input_tokens: 100, output_tokens: 50
                 "exact match"
               else
                 "not matched"
               end

      expect(result).to eq("exact match")
    end
  end

  describe "immutability" do
    it "creates frozen instances" do
      usage = described_class.new(input_tokens: 100, output_tokens: 50)
      expect(usage).to be_frozen
    end

    it "with method returns new frozen instance" do
      usage = described_class.new(input_tokens: 100, output_tokens: 50)
      updated = usage.with(input_tokens: 200)
      expect(updated).to be_frozen
      expect(usage.input_tokens).to eq(100) # original unchanged
    end
  end
end

RSpec.describe Smolagents::Timing do
  describe ".start_now" do
    it "creates timing with start_time set" do
      timing = described_class.start_now
      expect(timing.start_time).to be_a(Time)
      expect(timing.end_time).to be_nil
    end

    it "captures current time" do
      before = Time.now
      timing = described_class.start_now
      after = Time.now

      expect(timing.start_time).to be_between(before, after)
    end

    it "is immutable" do
      timing = described_class.start_now
      expect(timing).to be_frozen
    end
  end

  describe "#stop" do
    it "returns new timing with end_time set" do
      timing = described_class.start_now
      stopped = timing.stop
      expect(stopped.end_time).to be_a(Time)
      expect(stopped.end_time).to be >= stopped.start_time
    end

    it "does not mutate original timing" do
      timing = described_class.start_now
      original_end = timing.end_time
      stopped = timing.stop

      expect(timing.end_time).to equal(original_end)
      expect(stopped.end_time).not_to be_nil
    end

    it "can be called multiple times" do
      timing = described_class.start_now
      stopped1 = timing.stop
      stopped2 = timing.stop

      # Both should have end_time, but different values (time moved on)
      expect(stopped1.end_time).to be_a(Time)
      expect(stopped2.end_time).to be_a(Time)
      expect(stopped2.end_time).to be >= stopped1.end_time
    end
  end

  describe "#duration" do
    it "returns nil when not stopped" do
      timing = described_class.start_now
      expect(timing.duration).to be_nil
    end

    it "returns duration in seconds when stopped" do
      # Use explicit times to test calculation, not real elapsed time
      start_time = Time.now
      timing = described_class.new(start_time:, end_time: start_time + 2.5)

      expect(timing.duration).to eq(2.5)
    end

    it "calculates positive duration" do
      start_time = Time.now
      timing = described_class.new(start_time:, end_time: start_time + 5.0)

      expect(timing.duration).to eq(5.0)
    end

    it "handles small durations" do
      start_time = Time.now
      end_time = start_time + 0.001
      timing = described_class.new(start_time:, end_time:)

      expect(timing.duration).to be_within(0.0001).of(0.001)
    end

    it "handles zero duration" do
      start_time = Time.now
      timing = described_class.new(start_time:, end_time: start_time)

      expect(timing.duration).to eq(0.0)
    end
  end

  describe "#to_h" do
    it "returns hash with all fields" do
      start_time = Time.now
      timing = described_class.new(start_time:, end_time: start_time + 3.0)
      hash = timing.to_h

      expect(hash.keys).to contain_exactly(:start_time, :end_time, :duration)
      expect(hash[:start_time]).to eq(start_time)
      expect(hash[:end_time]).to eq(start_time + 3.0)
      expect(hash[:duration]).to eq(3.0)
    end

    it "includes nil duration when not stopped" do
      timing = described_class.start_now
      hash = timing.to_h

      expect(hash[:duration]).to be_nil
    end

    it "preserves timing precision" do
      start_time = Time.now
      end_time = start_time + 1.234567
      timing = described_class.new(start_time:, end_time:)
      hash = timing.to_h

      expect(hash[:start_time]).to eq(start_time)
      expect(hash[:end_time]).to eq(end_time)
      expect(hash[:duration]).to be_within(0.0001).of(1.234567)
    end
  end

  describe "pattern matching" do
    it "matches on start_time" do
      timing = described_class.start_now
      start = timing.start_time

      result = case timing
               in start_time: ^start
                 "matched"
               else
                 "not matched"
               end

      expect(result).to eq("matched")
    end

    it "matches on end_time being nil" do
      timing = described_class.start_now

      result = case timing
               in end_time: nil
                 "not stopped"
               else
                 "stopped"
               end

      expect(result).to eq("not stopped")
    end
  end

  describe "immutability" do
    it "creates frozen instances" do
      timing = described_class.start_now
      expect(timing).to be_frozen
    end

    it "with method returns new frozen instance" do
      timing = described_class.start_now
      updated = timing.with(end_time: Time.now)
      expect(updated).to be_frozen
    end
  end
end

RSpec.describe Smolagents::ToolCall do
  describe "#to_h" do
    it "returns hash in API format" do
      tool_call = described_class.new(
        name: "web_search",
        arguments: { query: "test" },
        id: "call_123"
      )

      expect(tool_call.to_h).to eq({
                                     id: "call_123",
                                     type: "function",
                                     function: {
                                       name: "web_search",
                                       arguments: { query: "test" }
                                     }
                                   })
    end

    it "handles complex arguments" do
      tool_call = described_class.new(
        name: "api_call",
        arguments: { endpoint: "/users", params: { limit: 10, offset: 0 }, headers: { auth: "token" } },
        id: "call_456"
      )
      hash = tool_call.to_h

      expect(hash[:type]).to eq("function")
      expect(hash[:function][:arguments][:params][:limit]).to eq(10)
      expect(hash[:function][:arguments][:headers][:auth]).to eq("token")
    end

    it "handles empty arguments" do
      tool_call = described_class.new(
        name: "no_args_tool",
        arguments: {},
        id: "call_789"
      )

      expect(tool_call.to_h[:function][:arguments]).to eq({})
    end

    it "always sets type to 'function'" do
      tool_call = described_class.new(name: "test", arguments: {}, id: "call_1")
      expect(tool_call.to_h[:type]).to eq("function")
    end

    it "preserves all required fields" do
      tool_call = described_class.new(name: "search", arguments: { q: "test" }, id: "call_999")
      hash = tool_call.to_h

      expect(hash).to have_key(:id)
      expect(hash).to have_key(:type)
      expect(hash).to have_key(:function)
      expect(hash[:function]).to have_key(:name)
      expect(hash[:function]).to have_key(:arguments)
    end
  end

  describe "immutability" do
    it "creates frozen instances" do
      tool_call = described_class.new(name: "search", arguments: {}, id: "call_1")
      expect(tool_call).to be_frozen
    end

    it "with method returns new frozen instance" do
      tool_call = described_class.new(name: "search", arguments: {}, id: "call_1")
      updated = tool_call.with(name: "new_search")
      expect(updated).to be_frozen
      expect(tool_call.name).to eq("search")
    end
  end

  describe "pattern matching" do
    it "matches on name" do
      tool_call = described_class.new(name: "search", arguments: {}, id: "call_1")

      result = case tool_call
               in name: "search"
                 "matched"
               else
                 "not matched"
               end

      expect(result).to eq("matched")
    end

    it "matches on id" do
      tool_call = described_class.new(name: "search", arguments: {}, id: "call_123")

      result = case tool_call
               in id: "call_123"
                 "matched"
               else
                 "not matched"
               end

      expect(result).to eq("matched")
    end
  end
end

RSpec.describe Smolagents::RunContext do
  describe ".start" do
    it "creates context at step 1 with zero tokens" do
      context = described_class.start

      expect(context.step_number).to eq(1)
      expect(context.total_tokens).to eq(Smolagents::TokenUsage.zero)
      expect(context.timing.start_time).to be_a(Time)
      expect(context.timing.end_time).to be_nil
    end

    it "is immutable" do
      context = described_class.start
      expect(context).to be_frozen
    end

    it "timing is started (not stopped)" do
      context = described_class.start
      expect(context.timing.duration).to be_nil
    end
  end

  describe "#advance" do
    it "returns new context with incremented step number" do
      context = described_class.start
      advanced = context.advance

      expect(advanced.step_number).to eq(2)
      expect(context.step_number).to eq(1) # immutable
    end

    it "preserves other fields" do
      context = described_class.start
      usage = Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      context = context.add_tokens(usage)
      advanced = context.advance

      expect(advanced.total_tokens).to eq(context.total_tokens)
      expect(advanced.timing).to eq(context.timing)
    end

    it "can advance multiple times" do
      context = described_class.start
      c2 = context.advance
      c3 = c2.advance
      c4 = c3.advance

      expect(context.step_number).to eq(1)
      expect(c2.step_number).to eq(2)
      expect(c3.step_number).to eq(3)
      expect(c4.step_number).to eq(4)
    end

    it "returns frozen instance" do
      context = described_class.start
      advanced = context.advance
      expect(advanced).to be_frozen
    end
  end

  describe "#add_tokens" do
    it "accumulates token usage" do
      context = described_class.start
      usage = Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50)

      updated = context.add_tokens(usage)

      expect(updated.total_tokens.input_tokens).to eq(100)
      expect(updated.total_tokens.output_tokens).to eq(50)
    end

    it "returns self when usage is nil" do
      context = described_class.start
      updated = context.add_tokens(nil)

      expect(updated).to eq(context)
    end

    it "accumulates multiple token usages" do
      context = described_class.start
      usage1 = Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      usage2 = Smolagents::TokenUsage.new(input_tokens: 200, output_tokens: 75)

      updated = context.add_tokens(usage1).add_tokens(usage2)

      expect(updated.total_tokens.input_tokens).to eq(300)
      expect(updated.total_tokens.output_tokens).to eq(125)
    end

    it "preserves other fields when adding tokens" do
      context = described_class.start
      advanced = context.advance
      usage = Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      updated = advanced.add_tokens(usage)

      expect(updated.step_number).to eq(2)
      expect(updated.total_tokens.total_tokens).to eq(150)
    end

    it "returns frozen instance" do
      context = described_class.start
      usage = Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      updated = context.add_tokens(usage)
      expect(updated).to be_frozen
    end
  end

  describe "#finish" do
    it "stops the timing" do
      context = described_class.start
      finished = context.finish

      # Verify structural properties: timing is stopped (has end_time)
      expect(finished.timing.end_time).to be_a(Time)
      expect(finished.timing.duration).to be_a(Float)
    end

    it "preserves step number and tokens when finishing" do
      context = described_class.start.advance.advance
      usage = Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      context = context.add_tokens(usage)
      finished = context.finish

      expect(finished.step_number).to eq(3)
      expect(finished.total_tokens).to eq(usage)
    end

    it "returns frozen instance" do
      context = described_class.start
      finished = context.finish
      expect(finished).to be_frozen
    end
  end

  describe "#exceeded?" do
    it "returns false when step_number <= max_steps" do
      context = described_class.start
      expect(context.exceeded?(5)).to be false
    end

    it "returns true when step_number > max_steps" do
      context = described_class.start.advance.advance # step 3
      expect(context.exceeded?(2)).to be true
    end

    it "returns false when step_number == max_steps" do
      context = described_class.start.advance.advance # step 3
      expect(context.exceeded?(3)).to be false
    end

    it "works with large max_steps" do
      context = described_class.start.advance
      expect(context.exceeded?(1_000_000)).to be false
    end

    it "returns true for very large step numbers" do
      context = described_class.start
      100.times { context = context.advance }
      expect(context.exceeded?(50)).to be true
    end
  end

  describe "#steps_completed" do
    it "returns step_number - 1" do
      context = described_class.start.advance.advance # step 3
      expect(context.steps_completed).to eq(2)
    end

    it "returns 0 when at step 1" do
      context = described_class.start
      expect(context.steps_completed).to eq(0)
    end

    it "works with many steps" do
      context = described_class.start
      10.times { context = context.advance }
      expect(context.step_number).to eq(11)
      expect(context.steps_completed).to eq(10)
    end
  end

  describe "pattern matching" do
    it "matches on step_number" do
      context = described_class.start.advance

      result = case context
               in step_number: 2
                 "step 2"
               else
                 "other"
               end

      expect(result).to eq("step 2")
    end

    it "matches on total_tokens" do
      context = described_class.start
      usage = Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      context = context.add_tokens(usage)

      result = case context
               in total_tokens: { input_tokens: 100 }
                 "matched"
               else
                 "not matched"
               end

      expect(result).to eq("matched")
    end
  end
end

RSpec.describe Smolagents::ToolOutput do
  let(:tool_call) { Smolagents::ToolCall.new(name: "search", arguments: { q: "test" }, id: "call_123") }

  describe ".from_call" do
    it "creates output from tool call" do
      output = described_class.from_call(tool_call, output: "result", observation: "search: result")

      expect(output.id).to eq("call_123")
      expect(output.output).to eq("result")
      expect(output.observation).to eq("search: result")
      expect(output.is_final_answer).to be false
      expect(output.tool_call).to eq(tool_call)
    end

    it "supports is_final flag" do
      output = described_class.from_call(tool_call, output: "done", observation: "final", is_final: true)

      expect(output.is_final_answer).to be true
    end

    it "handles empty output" do
      output = described_class.from_call(tool_call, output: "", observation: "no result")

      expect(output.output).to eq("")
    end

    it "handles long output" do
      long_output = "x" * 10_000
      output = described_class.from_call(tool_call, output: long_output, observation: "long result")

      expect(output.output).to eq(long_output)
    end

    it "preserves tool_call reference" do
      output = described_class.from_call(tool_call, output: "result", observation: "ok")

      expect(output.tool_call).to equal(tool_call)
    end

    it "has is_final_answer false by default" do
      output = described_class.from_call(tool_call, output: "result", observation: "ok")

      expect(output.is_final_answer).to be false
    end

    it "is frozen" do
      output = described_class.from_call(tool_call, output: "result", observation: "ok")

      expect(output).to be_frozen
    end
  end

  describe ".error" do
    it "creates error output" do
      output = described_class.error(id: "err_1", observation: "Something went wrong")

      expect(output.id).to eq("err_1")
      expect(output.output).to be_nil
      expect(output.is_final_answer).to be false
      expect(output.observation).to eq("Something went wrong")
      expect(output.tool_call).to be_nil
    end

    it "handles detailed error messages" do
      error_msg = "Tool not found: 'invalid_tool'. Available: ['search', 'read_file']"
      output = described_class.error(id: "err_2", observation: error_msg)

      expect(output.observation).to eq(error_msg)
    end

    it "is frozen" do
      output = described_class.error(id: "err_1", observation: "error")

      expect(output).to be_frozen
    end
  end

  describe "#to_h" do
    it "returns hash with all fields" do
      output = described_class.from_call(tool_call, output: "result", observation: "ok")
      hash = output.to_h

      expect(hash).to have_key(:id)
      expect(hash).to have_key(:output)
      expect(hash).to have_key(:is_final_answer)
      expect(hash).to have_key(:observation)
      expect(hash).to have_key(:tool_call)
    end

    it "converts tool_call to hash" do
      output = described_class.from_call(tool_call, output: "result", observation: "ok")
      hash = output.to_h

      expect(hash[:tool_call]).to be_a(Hash)
      expect(hash[:tool_call][:id]).to eq("call_123")
    end

    it "handles nil tool_call in error output" do
      output = described_class.error(id: "err_1", observation: "error")
      hash = output.to_h

      expect(hash[:tool_call]).to be_nil
    end
  end

  describe "pattern matching" do
    it "matches on is_final_answer" do
      output = described_class.from_call(tool_call, output: "result", observation: "ok", is_final: true)

      result = case output
               in is_final_answer: true
                 "final"
               else
                 "not final"
               end

      expect(result).to eq("final")
    end

    it "matches on id" do
      output = described_class.from_call(tool_call, output: "result", observation: "ok")

      result = case output
               in id: "call_123"
                 "matched"
               else
                 "not matched"
               end

      expect(result).to eq("matched")
    end
  end
end

RSpec.describe Smolagents::RunResult do
  let(:timing) { Smolagents::Timing.new(start_time: Time.now, end_time: Time.now + 1.0) }
  let(:token_usage) { Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50) }

  describe "#success?" do
    it "returns true when state is :success" do
      result = described_class.new(
        output: "done",
        state: :success,
        steps: [],
        token_usage: nil,
        timing: nil
      )
      expect(result.success?).to be true
    end

    it "returns false when state is not :success" do
      result = described_class.new(
        output: nil,
        state: :max_steps_reached,
        steps: [],
        token_usage: nil,
        timing: nil
      )
      expect(result.success?).to be false
    end

    it "returns false for other states" do
      %i[failure partial error timeout].each do |state|
        result = described_class.new(output: nil, state:, steps: [], token_usage: nil, timing: nil)
        expect(result.success?).to be false
      end
    end
  end

  describe "#partial?" do
    it "returns true when state is :partial" do
      result = described_class.new(output: "partial", state: :partial, steps: [], token_usage: nil, timing: nil)
      expect(result.partial?).to be true
    end

    it "returns false for other states" do
      %i[success failure error timeout max_steps_reached].each do |state|
        result = described_class.new(output: nil, state:, steps: [], token_usage: nil, timing: nil)
        expect(result.partial?).to be false
      end
    end
  end

  describe "#failure?" do
    it "returns true when state is :failure" do
      result = described_class.new(output: nil, state: :failure, steps: [], token_usage: nil, timing: nil)
      expect(result.failure?).to be true
    end

    it "returns false for other states" do
      %i[success partial error timeout max_steps_reached].each do |state|
        result = described_class.new(output: nil, state:, steps: [], token_usage: nil, timing: nil)
        expect(result.failure?).to be false
      end
    end
  end

  describe "#error?" do
    it "returns true when state is :error" do
      result = described_class.new(output: nil, state: :error, steps: [], token_usage: nil, timing: nil)
      expect(result.error?).to be true
    end

    it "returns false for other states" do
      %i[success failure partial timeout max_steps_reached].each do |state|
        result = described_class.new(output: nil, state:, steps: [], token_usage: nil, timing: nil)
        expect(result.error?).to be false
      end
    end
  end

  # NOTE: max_steps? and timeout? methods reference Outcome.max_steps? and Outcome.timeout?
  # which are not yet implemented in the Outcome module. These tests are skipped until
  # those methods are added to lib/smolagents/types/outcome.rb

  describe "#terminal?" do
    it "returns true for terminal states" do
      %i[success failure error timeout].each do |state|
        result = described_class.new(output: nil, state:, steps: [], token_usage: nil, timing: nil)
        expect(result.terminal?).to be true
      end
    end

    it "returns false for non-terminal states" do
      %i[partial max_steps_reached].each do |state|
        result = described_class.new(output: nil, state:, steps: [], token_usage: nil, timing: nil)
        expect(result.terminal?).to be false
      end
    end
  end

  describe "#retriable?" do
    it "returns true for retriable states" do
      %i[partial max_steps_reached].each do |state|
        result = described_class.new(output: nil, state:, steps: [], token_usage: nil, timing: nil)
        expect(result.retriable?).to be true
      end
    end

    it "returns false for non-retriable states" do
      %i[success failure error timeout].each do |state|
        result = described_class.new(output: nil, state:, steps: [], token_usage: nil, timing: nil)
        expect(result.retriable?).to be false
      end
    end
  end

  describe "#outcome" do
    it "returns the state" do
      result = described_class.new(output: nil, state: :success, steps: [], token_usage: nil, timing: nil)
      expect(result.outcome).to eq(:success)
    end

    it "is an alias for state" do
      result = described_class.new(output: nil, state: :failure, steps: [], token_usage: nil, timing: nil)
      expect(result.outcome).to eq(result.state)
    end
  end

  describe "#duration" do
    it "returns duration from timing" do
      result = described_class.new(output: "test", state: :success, steps: [], token_usage: nil, timing:)
      expect(result.duration).to be_within(0.01).of(1.0)
    end

    it "returns nil when timing is nil" do
      result = described_class.new(output: "test", state: :success, steps: [], token_usage: nil, timing: nil)
      expect(result.duration).to be_nil
    end

    it "returns nil when timing has no end_time" do
      started = Smolagents::Timing.start_now
      result = described_class.new(output: "test", state: :success, steps: [], token_usage: nil, timing: started)
      expect(result.duration).to be_nil
    end
  end

  describe "#step_count" do
    it "counts only ActionStep instances" do
      action_step = Smolagents::ActionStep.new(step_number: 1)
      result = described_class.new(output: nil, state: :success, steps: [action_step], token_usage: nil, timing: nil)
      expect(result.step_count).to eq(1)
    end

    it "ignores non-ActionStep steps" do
      task_step = Smolagents::TaskStep.new(task: "test", task_images: [])
      result = described_class.new(output: nil, state: :success, steps: [task_step], token_usage: nil, timing: nil)
      expect(result.step_count).to eq(0)
    end

    it "counts multiple ActionSteps" do
      steps = (1..5).map { |n| Smolagents::ActionStep.new(step_number: n) }
      result = described_class.new(output: nil, state: :success, steps:, token_usage: nil, timing: nil)
      expect(result.step_count).to eq(5)
    end
  end

  describe "#action_steps" do
    it "returns only ActionStep instances" do
      action_steps = (1..3).map { |n| Smolagents::ActionStep.new(step_number: n) }
      task_step = Smolagents::TaskStep.new(task: "test", task_images: [])
      result = described_class.new(
        output: nil,
        state: :success,
        steps: action_steps + [task_step],
        token_usage: nil,
        timing: nil
      )

      expect(result.action_steps).to eq(action_steps)
      expect(result.action_steps.all?(Smolagents::ActionStep)).to be true
    end
  end

  describe "#summary" do
    it "includes outcome and step count" do
      steps = (1..2).map { |n| Smolagents::ActionStep.new(step_number: n, timing:) }
      result = described_class.new(
        output: "answer",
        state: :success,
        steps:,
        token_usage:,
        timing:
      )
      summary = result.summary

      expect(summary).to include("success")
      expect(summary).to include("2 steps")
    end

    it "includes token usage" do
      result = described_class.new(
        output: "answer",
        state: :success,
        steps: [],
        token_usage:,
        timing:
      )
      summary = result.summary

      expect(summary).to include("150")
      expect(summary).to include("100 in")
      expect(summary).to include("50 out")
    end

    it "truncates long output" do
      long_output = "x" * 200
      result = described_class.new(
        output: long_output,
        state: :success,
        steps: [],
        token_usage: nil,
        timing:
      )
      summary = result.summary

      expect(summary).to include("...")
      expect(summary.length).to be < long_output.length
    end

    it "handles nil output" do
      result = described_class.new(output: nil, state: :failure, steps: [], token_usage: nil, timing:)
      summary = result.summary
      expect(summary).to include("failure")
    end
  end

  describe "#to_h" do
    it "returns hash with all fields" do
      result = described_class.new(
        output: "test",
        state: :success,
        steps: [],
        token_usage:,
        timing:
      )
      hash = result.to_h

      expect(hash).to have_key(:output)
      expect(hash).to have_key(:state)
      expect(hash).to have_key(:steps)
      expect(hash).to have_key(:token_usage)
      expect(hash).to have_key(:timing)
    end

    it "converts token_usage and timing to hashes" do
      result = described_class.new(
        output: "test",
        state: :success,
        steps: [],
        token_usage:,
        timing:
      )
      hash = result.to_h

      expect(hash[:token_usage]).to be_a(Hash)
      expect(hash[:timing]).to be_a(Hash)
    end

    it "handles nil values in to_h" do
      result = described_class.new(output: nil, state: :failure, steps: [], token_usage: nil, timing: nil)
      hash = result.to_h

      expect(hash[:token_usage]).to be_nil
      expect(hash[:timing]).to be_nil
    end
  end

  describe "pattern matching" do
    it "matches on success state" do
      result = described_class.new(output: "yes", state: :success, steps: [], token_usage: nil, timing: nil)

      matched = case result
                in state: :success
                  true
                else
                  false
                end

      expect(matched).to be true
    end

    it "matches on output" do
      result = described_class.new(output: "specific answer", state: :success, steps: [], token_usage: nil, timing: nil)

      matched = case result
                in output: "specific answer"
                  true
                else
                  false
                end

      expect(matched).to be true
    end
  end

  describe "immutability" do
    it "creates frozen instances" do
      result = described_class.new(output: "test", state: :success, steps: [], token_usage: nil, timing: nil)
      expect(result).to be_frozen
    end

    it "with method returns new frozen instance" do
      result = described_class.new(output: "test", state: :success, steps: [], token_usage: nil, timing: nil)
      updated = result.with(output: "updated")
      expect(updated).to be_frozen
      expect(result.output).to eq("test")
    end
  end
end
