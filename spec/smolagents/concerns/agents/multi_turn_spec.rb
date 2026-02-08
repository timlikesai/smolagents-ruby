require "smolagents"

RSpec.describe Smolagents::Concerns::MultiTurn do
  let(:mock_result) do
    Smolagents::Types::RunResult.success(output: "result", steps: [], token_usage: nil, timing: nil)
  end

  let(:test_class) do
    result_ref = mock_result
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::MultiTurn

      attr_accessor :memory

      define_method(:initialize) do |max_turns: nil|
        initialize_multi_turn(max_turns:)
        @memory = nil
        @run_calls = []
      end

      define_method(:run) do |task, stream: false, reset: true, images: nil|
        @run_calls << { task:, stream:, reset:, images: }
        result_ref
      end

      define_method(:run_calls) { @run_calls }
    end
  end

  let(:agent) { test_class.new }

  describe "#initialize_multi_turn" do
    it "sets turn_number to 0" do
      expect(agent.turn_number).to eq(0)
    end

    it "initializes empty conversation_turns" do
      expect(agent.conversation_turns).to eq([])
    end

    it "sets max_turns when provided" do
      limited = test_class.new(max_turns: 5)
      expect(limited.max_turns).to eq(5)
    end

    it "defaults max_turns to nil" do
      expect(agent.max_turns).to be_nil
    end
  end

  describe "#continue" do
    it "calls run with reset: false" do
      agent.continue("hello")

      expect(agent.run_calls.size).to eq(1)
      expect(agent.run_calls.first[:reset]).to be false
    end

    it "passes stream and images options to run" do
      agent.continue("hello", stream: true, images: ["img.png"])

      call = agent.run_calls.first
      expect(call[:stream]).to be true
      expect(call[:images]).to eq(["img.png"])
    end

    it "increments turn_number" do
      agent.continue("first")
      expect(agent.turn_number).to eq(1)

      agent.continue("second")
      expect(agent.turn_number).to eq(2)
    end

    it "records ConversationTurn in conversation_turns" do
      agent.continue("hello")

      expect(agent.conversation_turns.size).to eq(1)
      turn = agent.conversation_turns.first
      expect(turn).to be_a(Smolagents::Types::ConversationTurn)
      expect(turn.turn_number).to eq(0)
      expect(turn.task).to eq("hello")
    end

    it "returns the RunResult from run" do
      result = agent.continue("hello")
      expect(result).to eq(mock_result)
    end

    it "emits turn_started and turn_completed lifecycle events" do
      events = []
      queue = Thread::Queue.new
      agent.connect_to(queue)

      agent.continue("hello")
      queue.close

      while (event = queue.pop)
        events << event
      end

      phases = events.select { |e| e.is_a?(Smolagents::Events::TaskLifecycle) }.map(&:phase)
      expect(phases).to eq(%i[turn_started turn_completed])
    end
  end

  describe "max_turns enforcement" do
    it "raises when max_turns exceeded" do
      limited = test_class.new(max_turns: 2)
      limited.continue("first")
      limited.continue("second")

      expect { limited.continue("third") }.to raise_error(RuntimeError, /Max turns \(2\) exceeded/)
    end

    it "allows exactly max_turns invocations" do
      limited = test_class.new(max_turns: 1)
      expect { limited.continue("first") }.not_to raise_error
      expect { limited.continue("second") }.to raise_error(RuntimeError)
    end
  end

  describe "#reset_conversation!" do
    it "resets turn_number to 0" do
      agent.continue("hello")
      agent.reset_conversation!

      expect(agent.turn_number).to eq(0)
    end

    it "clears conversation_turns" do
      agent.continue("hello")
      agent.reset_conversation!

      expect(agent.conversation_turns).to eq([])
    end

    it "resets memory when present" do
      memory = double("memory")
      allow(memory).to receive(:reset)
      agent.memory = memory

      agent.reset_conversation!

      expect(memory).to have_received(:reset)
    end
  end

  describe "#multi_turn?" do
    it "returns true when initialized" do
      expect(agent.multi_turn?).to be true
    end

    it "returns falsey when not initialized" do
      bare_class = Class.new { include Smolagents::Concerns::MultiTurn }
      bare = bare_class.allocate
      expect(bare).not_to be_multi_turn
    end
  end

  describe "lazy initialization via ensure_multi_turn_initialized" do
    it "auto-initializes on continue when not explicitly initialized" do
      lazy_class = Class.new do
        include Smolagents::Events::Emitter
        include Smolagents::Concerns::MultiTurn

        attr_accessor :memory

        def run(task, stream: false, reset: true, images: nil)
          Smolagents::Types::RunResult.success(output: task, steps: [], token_usage: nil, timing: nil)
        end
      end

      lazy = lazy_class.new
      expect(lazy).not_to be_multi_turn

      lazy.continue("hello")
      expect(lazy).to be_multi_turn
      expect(lazy.turn_number).to eq(1)
    end
  end
end
