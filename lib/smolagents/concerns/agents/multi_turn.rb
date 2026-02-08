module Smolagents
  module Concerns
    # Multi-turn conversation support for agents.
    #
    # Enables agents to maintain context across multiple user messages.
    # Each turn gets a fresh step budget while memory accumulates.
    #
    # @example
    #   agent = Smolagents.agent.model { m }.conversation_mode.build
    #   result1 = agent.run("What is Ruby?")
    #   result2 = agent.continue("Tell me more about its type system")
    #   agent.conversation_turns  #=> [ConversationTurn, ConversationTurn]
    module MultiTurn
      # @return [Integer] Current turn number (0-based)
      attr_reader :turn_number

      # @return [Array<Types::ConversationTurn>] All completed turns
      attr_reader :conversation_turns

      # @return [Integer] Maximum allowed turns (nil = unlimited)
      attr_reader :max_turns

      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
      end

      # Initialize multi-turn state (called lazily on first continue).
      # @param max_turns [Integer, nil] Maximum turns (nil = unlimited)
      def initialize_multi_turn(max_turns: nil)
        @turn_number = 0
        @conversation_turns = []
        @max_turns = max_turns
        @multi_turn_enabled = true
      end

      # Continue the conversation with a new message.
      # @param message [String] The next user message
      # @param stream [Boolean] Stream mode
      # @param images [Array, nil] Images for multimodal
      # @return [Types::RunResult] Result of this turn
      def continue(message, stream: false, images: nil)
        ensure_multi_turn_initialized
        raise "Max turns (#{@max_turns}) exceeded" if @max_turns && @turn_number >= @max_turns

        emit :task_lifecycle, phase: :turn_started, task: message, agent_name: self.class.name
        run(message, stream:, reset: false, images:).tap do |result|
          record_turn(message, result)
          emit :task_lifecycle, phase: :turn_completed, task: message,
                                outcome: result.state, steps_taken: result.step_count
        end
      end

      # Reset conversation state completely.
      # @return [void]
      def reset_conversation!
        ensure_multi_turn_initialized
        @turn_number = 0
        @conversation_turns = []
        @memory&.reset
      end

      # Whether multi-turn is enabled.
      # @return [Boolean]
      def multi_turn?
        defined?(@multi_turn_enabled) && @multi_turn_enabled == true
      end

      private

      def ensure_multi_turn_initialized
        return if defined?(@multi_turn_enabled)

        initialize_multi_turn
      end

      def record_turn(task, result)
        turn = Types::ConversationTurn.create(
          turn_number: @turn_number, task:,
          steps: result.steps || [], token_usage: result.token_usage, timing: result.timing
        )
        @conversation_turns << turn
        @turn_number += 1
      end
    end
  end
end
