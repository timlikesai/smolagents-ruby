require "monitor"

module Smolagents
  module Testing
    # Immutable record of a generate() call for inspection.
    #
    # @example Inspecting a recorded call
    #   call = model.last_call
    #   call.index           # => 1
    #   call.system_message? # => true
    #   call.user_messages   # => [ChatMessage(...)]
    #   call.last_user_content  # => "What is 2+2?"
    #
    # @see MockModel
    MockCall = Data.define(:index, :messages, :tools_to_call_from, :timestamp) do
      # Checks if this call included a system message.
      # @return [Boolean]
      def system_message? = messages.any? { |m| m.role == Types::MessageRole::SYSTEM }

      # Returns all user messages from this call.
      # @return [Array<ChatMessage>]
      def user_messages = messages.select { |m| m.role == Types::MessageRole::USER }

      # Returns all assistant messages from this call.
      # @return [Array<ChatMessage>]
      def assistant_messages = messages.select { |m| m.role == Types::MessageRole::ASSISTANT }

      # Returns the content of the last user message.
      # @return [String, nil]
      def last_user_content = user_messages.last&.content

      # Hash-style access for backwards compatibility.
      # @param key [Symbol] The key to access (:index, :messages, :tools_to_call_from, :timestamp)
      # @return [Object] The value for the key
      def [](key) = public_send(key)

      # Hash-style dig for backwards compatibility.
      # @param keys [Array<Symbol>] Keys to dig through
      # @return [Object, nil] The nested value
      def dig(*keys)
        keys.reduce(self) do |obj, key|
          return nil if obj.nil?

          obj.respond_to?(:[]) ? obj[key] : obj.public_send(key)
        end
      end
    end

    # Deterministic model for testing agent behavior without LLM calls.
    #
    # MockModel extends the base Model class to provide precise control over
    # model responses in tests. Queue responses in order, then run your agent
    # and verify the model received the expected messages.
    #
    # Thread-safe for use in concurrent tests via Monitor (re-entrant safe).
    #
    # @example Basic usage
    #   require "smolagents/testing"
    #
    #   model = Smolagents::Testing::MockModel.new
    #   model.queue_final_answer("42")
    #
    #   agent = Smolagents.agent.model { model }.build
    #   result = agent.run("What is the answer?")
    #
    #   expect(result.output).to eq("42")
    #   expect(model.call_count).to eq(1)
    #
    # @example Multi-step agent test
    #   model = Smolagents::Testing::MockModel.new
    #   model.queue_code_action("search(query: 'Ruby 4.0')")
    #   model.queue_final_answer("Ruby 4.0 was released in 2024")
    #
    #   agent = Smolagents.agent.model { model }.tools(:search).build
    #   result = agent.run("When was Ruby 4.0 released?")
    #
    #   expect(model.call_count).to eq(2)
    #   expect(model.user_messages_sent.first.content).to include("Ruby 4.0")
    #
    # @example Inspecting calls with fluent API
    #   model = Smolagents::Testing::MockModel.new
    #   model.answers("done")  # alias for queue_final_answer
    #
    #   agent.run("task")
    #
    #   expect(model.calls_with_system_prompt).not_to be_empty
    #   expect(model.last_call.user_messages.map(&:content)).to include("task")
    #
    # @example Chaining responses
    #   model = Smolagents::Testing::MockModel.new
    #   model
    #     .queue_code_action("step_one()")
    #     .queue_code_action("step_two()")
    #     .queue_final_answer("complete")
    #
    # @see Smolagents::Models::Model Base model class
    # @see Smolagents::Testing::Helpers Helper methods using MockModel
    class MockModel < Models::Model
      # @!attribute [r] calls
      #   @return [Array<MockCall>] All generate() calls with their arguments
      attr_reader :calls

      # @!attribute [r] call_count
      #   @return [Integer] Number of times generate() was called
      attr_reader :call_count

      # Creates a new MockModel.
      #
      # @param model_id [String] Identifier for this mock (default: "mock-model")
      # @example
      #   model = MockModel.new(model_id: "test-gpt4")
      def initialize(model_id: "mock-model")
        super
        @calls = []
        @call_count = 0
        @responses = []
        @monitor = Monitor.new
      end

      # Queues a response to be returned on the next generate() call.
      #
      # Responses are returned in FIFO order. Queue multiple responses
      # for multi-step agent tests.
      #
      # @param content [String, ChatMessage] The response content or message
      # @param input_tokens [Integer] Simulated input token count (default: 50)
      # @param output_tokens [Integer] Simulated output token count (default: 25)
      # @return [self] For method chaining
      #
      # @example Queue a simple response
      #   model.queue_response("Hello!")
      #
      # @example Queue with token usage
      #   model.queue_response("Complex answer", input_tokens: 200, output_tokens: 150)
      #
      # @example Chain multiple responses
      #   model.queue_response("Step 1").queue_response("Step 2")
      def queue_response(content, input_tokens: 50, output_tokens: 25)
        message = if content.is_a?(Types::ChatMessage)
                    content
                  else
                    Types::ChatMessage.assistant(
                      content,
                      token_usage: Types::TokenUsage.new(input_tokens:, output_tokens:)
                    )
                  end
        @monitor.synchronize { @responses << message }
        self
      end

      # Queues a code action response.
      #
      # Wraps the code in proper tags for CodeAgent parsing.
      #
      # @param code [String] Ruby code to execute
      # @return [self] For method chaining
      #
      # @example Queue a tool call
      #   model.queue_code_action("search(query: 'Ruby gems')")
      #
      # @example Queue multiple steps
      #   model.queue_code_action("result = search(query: 'test')")
      #   model.queue_code_action("final_answer(result)")
      def queue_code_action(code)
        queue_response("<code>\n#{code}\n</code>")
      end

      # Queues a final_answer call.
      #
      # Convenience for the common pattern of ending with final_answer().
      #
      # @param answer [String] The final answer to return
      # @return [self] For method chaining
      #
      # @example
      #   model.queue_final_answer("The answer is 42")
      def queue_final_answer(answer)
        queue_code_action("final_answer(#{answer.inspect})")
      end

      # Queues a planning response (pure text, no code).
      #
      # Useful for testing agents that separate planning from execution.
      #
      # @param plan [String] The planning text
      # @return [self] For method chaining
      #
      # @example
      #   model.queue_planning_response("I will: 1. Search 2. Summarize 3. Answer")
      def queue_planning_response(plan)
        queue_response(plan)
      end

      # Queues a tool call response (for ToolAgent JSON format).
      #
      # Creates a proper ChatMessage with tool_calls for agents using
      # the tool-calling interface instead of code generation.
      #
      # @param name [String] Tool name to call
      # @param arguments [Hash] Tool arguments
      # @param id [String] Tool call ID (auto-generated if not provided)
      # @return [self] For method chaining
      #
      # @example
      #   model.queue_tool_call("search", query: "Ruby 4.0")
      #   model.queue_tool_call("final_answer", answer: "Found it!")
      def queue_tool_call(name, id: SecureRandom.uuid, **arguments)
        tool_call = Types::ToolCall.new(name:, arguments:, id:)
        message = Types::ChatMessage.assistant(
          nil,
          tool_calls: [tool_call],
          token_usage: Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
        )
        @monitor.synchronize { @responses << message }
        self
      end

      # Generates a response by returning the next queued response.
      #
      # Records the call with all arguments for later inspection.
      # Raises if no more responses are queued.
      #
      # @param messages [Array<ChatMessage>] The conversation history
      # @param tools_to_call_from [Array<Tool>, nil] Available tools
      # @param kwargs [Hash] Additional options (ignored)
      # @return [ChatMessage] The next queued response
      # @raise [RuntimeError] When no more responses are queued
      #
      # @example Called automatically by agent
      #   agent.run("task")  # Calls model.generate() internally
      def generate(messages, tools_to_call_from: nil, **) # rubocop:disable Metrics/MethodLength
        @monitor.synchronize do
          @call_count += 1
          @calls << MockCall.new(
            index: @call_count,
            messages: messages.dup.freeze,
            tools_to_call_from: tools_to_call_from&.dup&.freeze,
            timestamp: Time.now
          )

          if @responses.empty?
            raise <<~ERROR.gsub(/\s+/, " ").strip
              MockModel: No more queued responses (call ##{@call_count}).
              Queue responses with queue_response(), queue_code_action(),
              queue_final_answer(), or queue_tool_call() before running agent.
            ERROR
          end

          @responses.shift
        end
      end

      # Returns the most recent generate() call.
      #
      # @return [MockCall, nil] Call data or nil if no calls made
      # @example
      #   model.last_call
      #   # => MockCall(index: 1, messages: [...], tools_to_call_from: [...], timestamp: ...)
      #   model.last_call.system_message?  # => true
      #   model.last_call.user_messages    # => [ChatMessage(...)]
      def last_call = @monitor.synchronize { @calls.last }

      # Returns the messages from the most recent call.
      #
      # @return [Array<ChatMessage>, nil] Messages or nil if no calls
      # @example
      #   model.last_messages.map(&:role)  # => [:system, :user]
      def last_messages = last_call&.messages

      # Resets all state (calls, responses, counter).
      #
      # Use between test cases when reusing a model instance.
      #
      # @return [self] For method chaining
      # @example
      #   model.reset!.queue_final_answer("new test")
      def reset!
        @monitor.synchronize do
          @calls.clear
          @responses.clear
          @call_count = 0
        end
        self
      end

      # Returns all calls that included a system prompt.
      #
      # @return [Array<MockCall>] Calls containing system messages
      # @example
      #   expect(model.calls_with_system_prompt.size).to eq(1)
      def calls_with_system_prompt
        @monitor.synchronize do
          @calls.select(&:system_message?)
        end
      end

      # Returns all user messages sent across all calls.
      #
      # Flattens messages from all calls and filters to user role.
      #
      # @return [Array<ChatMessage>] All user messages
      # @example
      #   prompts = model.user_messages_sent.map(&:content)
      def user_messages_sent
        @monitor.synchronize do
          @calls.flat_map(&:user_messages)
        end
      end

      # Returns all assistant messages from queued responses that were consumed.
      #
      # @return [Array<ChatMessage>] Assistant messages that were returned
      # @example
      #   model.queue_final_answer("42")
      #   agent.run("task")
      #   expect(model.assistant_messages_returned).not_to be_empty
      def assistant_messages_returned
        @monitor.synchronize do
          @calls.filter_map { |c| c[:response] }
        end
      end

      # Checks if all queued responses have been consumed.
      #
      # @return [Boolean] True if response queue is empty
      # @example
      #   expect(model).to be_exhausted
      def exhausted? = @monitor.synchronize { @responses.empty? }

      # Returns the number of unconsumed queued responses.
      #
      # @return [Integer] Remaining response count
      # @example
      #   model.queue_response("a").queue_response("b")
      #   model.remaining_responses  # => 2
      def remaining_responses = @monitor.synchronize { @responses.size }

      # Fluent API aliases for method chaining
      alias returns queue_response
      alias returns_code queue_code_action
      alias answers queue_final_answer
    end
  end
end
