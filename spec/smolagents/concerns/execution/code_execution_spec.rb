RSpec.describe Smolagents::Concerns::CodeExecution do
  before do
    stub_const("TestCodeAgent", Class.new do
      include Smolagents::Concerns::CodeExecution
      include Smolagents::Concerns::ManagedAgents

      attr_accessor :tools, :custom_instructions, :state, :model
      attr_reader :executor, :authorized_imports

      def initialize(tools: {}, model: nil, executor: nil, authorized_imports: nil, managed_agents: nil)
        @tools = tools
        @model = model
        @custom_instructions = ""
        @state = {}
        setup_managed_agents(managed_agents)
        setup_code_execution(executor:, authorized_imports:)
      end

      def write_memory_to_messages
        [Smolagents::ChatMessage.user("Test task")]
      end
    end)
  end

  let(:mock_executor) do
    instance_double(Smolagents::Executors::Executor,
                    send_tools: nil,
                    send_variables: nil,
                    execute: Smolagents::Executors::Executor::ExecutionResult.success(output: "result", logs: ""))
  end

  let(:mock_model) do
    instance_double(Smolagents::Models::Model)
  end

  let(:agent) do
    TestCodeAgent.new(
      tools: {},
      model: mock_model,
      executor: mock_executor,
      authorized_imports: %w[json csv]
    )
  end

  describe ".included" do
    it "adds executor and authorized_imports attributes" do
      expect(agent).to respond_to(:executor)
      expect(agent).to respond_to(:authorized_imports)
    end
  end

  describe "#setup_code_execution" do
    context "with custom executor and imports" do
      it "sets executor from parameter" do
        custom_executor = instance_double(Smolagents::Executors::Executor)
        agent.setup_code_execution(executor: custom_executor)

        expect(agent.executor).to eq(custom_executor)
      end

      it "sets authorized_imports from parameter" do
        agent.setup_code_execution(authorized_imports: %w[json yaml])

        expect(agent.authorized_imports).to eq(%w[json yaml])
      end

      it "sets both executor and imports" do
        custom_executor = instance_double(Smolagents::Executors::Executor)
        agent.setup_code_execution(
          executor: custom_executor,
          authorized_imports: %w[set ostruct]
        )

        expect(agent.executor).to eq(custom_executor)
        expect(agent.authorized_imports).to eq(%w[set ostruct])
      end
    end

    context "with defaults from configuration" do
      before do
        allow(Smolagents.configuration).to receive(:authorized_imports).and_return(["json"])
      end

      it "uses LocalRubyExecutor by default" do
        agent.setup_code_execution

        expect(agent.executor).to be_a(Smolagents::LocalRubyExecutor)
      end

      it "uses authorized_imports from configuration when not provided" do
        agent.setup_code_execution

        expect(agent.authorized_imports).to eq(["json"])
      end
    end
  end

  describe "#finalize_code_execution" do
    it "sends tools to executor" do
      search_tool = instance_double(Smolagents::Tool)
      agent.tools = { "search" => search_tool }

      allow(mock_executor).to receive(:send_tools).with({ "search" => search_tool })

      agent.finalize_code_execution

      expect(mock_executor).to have_received(:send_tools).with({ "search" => search_tool })
    end

    it "works with empty tools" do
      agent.tools = {}

      allow(mock_executor).to receive(:send_tools).with({})

      agent.finalize_code_execution

      expect(mock_executor).to have_received(:send_tools).with({})
    end

    it "handles multiple tools" do
      tool1 = instance_double(Smolagents::Tool)
      tool2 = instance_double(Smolagents::Tool)
      agent.tools = { "search" => tool1, "calculate" => tool2 }

      allow(mock_executor).to receive(:send_tools)

      agent.finalize_code_execution

      expect(mock_executor).to have_received(:send_tools) do |tools|
        expect(tools.keys).to contain_exactly("search", "calculate")
      end
    end
  end

  describe "#execute_step" do
    let(:action_step) do
      Smolagents::ActionStepBuilder.new(step_number: 0)
    end

    let(:response_message) do
      Smolagents::ChatMessage.assistant(
        "Here's the code:\n```ruby\nputs 'hello'\n```",
        tool_calls: nil
      )
    end

    before do
      allow(mock_model).to receive(:generate).and_return(response_message)
      allow(mock_executor).to receive(:execute)
        .and_return(Smolagents::Executors::Executor::ExecutionResult.success(output: "hello", logs: ""))
    end

    it "calls generate_code_response to get model output" do
      agent.execute_step(action_step)

      expect(mock_model).to have_received(:generate)
        .with([Smolagents::ChatMessage.user("Test task")], stop_sequences: nil)
    end

    it "updates action_step with model response and tokens" do
      token_usage = Smolagents::Types::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      response_with_tokens = Smolagents::ChatMessage.assistant(
        "```ruby\nputs 'hello'\n```",
        tool_calls: nil,
        token_usage:
      )
      allow(mock_model).to receive(:generate).and_return(response_with_tokens)

      agent.execute_step(action_step)

      expect(action_step.model_output_message).to eq(response_with_tokens)
      expect(action_step.token_usage).to eq(token_usage)
    end

    it "extracts and executes code from response" do
      agent.execute_step(action_step)

      expect(mock_executor).to have_received(:execute)
        .with("puts 'hello'", language: :ruby, timeout: 30)
    end

    it "returns early and sets error when no code found" do
      response_no_code = Smolagents::ChatMessage.assistant("No code here", tool_calls: nil)
      allow(mock_model).to receive(:generate).and_return(response_no_code)

      agent.execute_step(action_step)

      expect(action_step.error).to eq("No code block found in response")
      expect(mock_executor).not_to have_received(:execute)
    end

    it "stores code_action before execution" do
      agent.execute_step(action_step)

      expect(action_step.code_action).to eq("puts 'hello'")
    end

    it "sends state variables to executor before execution" do
      agent.state = { "query" => "test", "results" => [] }

      allow(mock_executor).to receive(:send_variables).with(agent.state)

      agent.execute_step(action_step)

      expect(mock_executor).to have_received(:send_variables).with(agent.state)
    end
  end

  describe "code parsing and extraction" do
    let(:action_step) do
      Smolagents::ActionStepBuilder.new(step_number: 0)
    end

    context "with standard markdown code block" do
      let(:response) do
        Smolagents::ChatMessage.assistant(
          "Let me search:\n```ruby\nsearch(query: 'ruby')\n```",
          tool_calls: nil
        )
      end

      before do
        allow(mock_model).to receive(:generate).and_return(response)
      end

      it "extracts ruby code block" do
        allow(mock_executor).to receive(:execute)
          .and_return(Smolagents::Executors::Executor::ExecutionResult.success(output: "result"))

        agent.execute_step(action_step)

        expect(action_step.code_action).to eq("search(query: 'ruby')")
      end
    end

    context "with generic markdown block (no language)" do
      let(:response) do
        Smolagents::ChatMessage.assistant(
          "Code:\n```\nresult = 2 + 2\n```",
          tool_calls: nil
        )
      end

      before do
        allow(mock_model).to receive(:generate).and_return(response)
      end

      it "extracts generic code block if it looks like Ruby" do
        allow(mock_executor).to receive(:execute)
          .and_return(Smolagents::Executors::Executor::ExecutionResult.success(output: "4"))

        agent.execute_step(action_step)

        expect(action_step.code_action).to eq("result = 2 + 2")
      end
    end

    context "with HTML code tags" do
      let(:response) do
        Smolagents::ChatMessage.assistant(
          "Try: <code>final_answer(answer: 42)</code>",
          tool_calls: nil
        )
      end

      before do
        allow(mock_model).to receive(:generate).and_return(response)
      end

      it "extracts HTML code tags" do
        allow(mock_executor).to receive(:execute)
          .and_return(Smolagents::Executors::Executor::ExecutionResult.success(output: "42"))

        agent.execute_step(action_step)

        expect(action_step.code_action).to eq("final_answer(answer: 42)")
      end
    end

    context "with code inside backticks without newline" do
      let(:response) do
        Smolagents::ChatMessage.assistant(
          "Code: ```rubyresult = search(query: 'test')\n```",
          tool_calls: nil
        )
      end

      before do
        allow(mock_model).to receive(:generate).and_return(response)
      end

      it "extracts code despite missing newline" do
        allow(mock_executor).to receive(:execute)
          .and_return(Smolagents::Executors::Executor::ExecutionResult.success(output: "result"))

        agent.execute_step(action_step)

        expect(action_step.code_action).to eq("result = search(query: 'test')")
      end
    end
  end

  describe "error handling in code execution" do
    let(:action_step) do
      Smolagents::ActionStepBuilder.new(step_number: 0)
    end

    let(:response_message) do
      Smolagents::ChatMessage.assistant(
        "```ruby\nresult = search(query: 'test')\n```",
        tool_calls: nil
      )
    end

    before do
      allow(mock_model).to receive(:generate).and_return(response_message)
    end

    context "when code execution fails" do
      it "sets error and observations from execution result" do
        failure_result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "NameError: undefined variable 'search'",
          logs: "Attempted to call undefined method"
        )
        allow(mock_executor).to receive(:execute).and_return(failure_result)

        agent.execute_step(action_step)

        expect(action_step.error).to eq("NameError: undefined variable 'search'")
        expect(action_step.observations).to eq("Attempted to call undefined method")
      end
    end

    context "when code execution succeeds" do
      it "sets observations from both logs and output for model visibility" do
        success_result = Smolagents::Executors::Executor::ExecutionResult.success(
          output: "Found 10 results",
          logs: "Searching database...",
          is_final_answer: false
        )
        allow(mock_executor).to receive(:execute).and_return(success_result)

        agent.execute_step(action_step)

        expect(action_step.error).to be_nil
        # Observations include both stdout and return value so model can see tool results
        expect(action_step.observations).to eq("Searching database...\nFound 10 results")
        expect(action_step.action_output).to eq("Found 10 results")
      end
    end

    context "when final_answer is called" do
      it "sets is_final_answer flag" do
        final_result = Smolagents::Executors::Executor::ExecutionResult.success(
          output: "The answer is 42",
          logs: "",
          is_final_answer: true
        )
        allow(mock_executor).to receive(:execute).and_return(final_result)

        agent.execute_step(action_step)

        expect(action_step.is_final_answer).to be true
      end
    end

    context "with execution timeout" do
      it "captures timeout error" do
        timeout_result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "Execution timeout after 30 seconds",
          logs: "Started executing code..."
        )
        allow(mock_executor).to receive(:execute).and_return(timeout_result)

        agent.execute_step(action_step)

        expect(action_step.error).to include("timeout")
      end
    end

    context "with syntax error in generated code" do
      it "captures syntax error" do
        syntax_result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "SyntaxError: unexpected token (line 1)",
          logs: ""
        )
        allow(mock_executor).to receive(:execute).and_return(syntax_result)

        agent.execute_step(action_step)

        expect(action_step.error).to include("SyntaxError")
      end
    end
  end

  describe "execution result application" do
    let(:action_step) do
      Smolagents::ActionStepBuilder.new(step_number: 0)
    end

    it "handles ExecutionResult with pattern matching (success case)" do
      response = Smolagents::ChatMessage.assistant("```ruby\nx = 1 + 1\n```", tool_calls: nil)
      allow(mock_model).to receive(:generate).and_return(response)

      result = Smolagents::Executors::Executor::ExecutionResult.success(
        output: 2,
        logs: "",
        is_final_answer: false
      )
      allow(mock_executor).to receive(:execute).and_return(result)

      agent.execute_step(action_step)

      expect(action_step.action_output).to eq(2)
      # Observations include return value so model can see results
      expect(action_step.observations).to eq("2")
      expect(action_step.error).to be_nil
    end

    it "handles ExecutionResult with pattern matching (error case)" do
      response = Smolagents::ChatMessage.assistant("```ruby\nresult = undefined_var\n```", tool_calls: nil)
      allow(mock_model).to receive(:generate).and_return(response)

      result = Smolagents::Executors::Executor::ExecutionResult.failure(
        error: "RuntimeError: something went wrong",
        logs: "Partial output before error"
      )
      allow(mock_executor).to receive(:execute).and_return(result)

      agent.execute_step(action_step)

      expect(action_step.error).to eq("RuntimeError: something went wrong")
      expect(action_step.observations).to eq("Partial output before error")
      expect(action_step.action_output).to be_nil
    end
  end

  describe "conditional logic branches" do
    let(:action_step) do
      Smolagents::ActionStepBuilder.new(step_number: 0)
    end

    context "when code extraction returns nil" do
      it "returns early without executing" do
        response = Smolagents::ChatMessage.assistant("No code here", tool_calls: nil)
        allow(mock_model).to receive(:generate).and_return(response)

        agent.execute_step(action_step)

        expect(mock_executor).not_to have_received(:execute)
        expect(action_step.code_action).to be_nil
        expect(action_step.error).to eq("No code block found in response")
      end
    end

    context "when code extraction succeeds" do
      it "proceeds to execution" do
        response = Smolagents::ChatMessage.assistant("```ruby\nputs 'ok'\n```", tool_calls: nil)
        allow(mock_model).to receive(:generate).and_return(response)
        allow(mock_executor).to receive(:execute)
          .and_return(Smolagents::Executors::Executor::ExecutionResult.success(output: "ok"))

        agent.execute_step(action_step)

        expect(mock_executor).to have_received(:execute)
        expect(action_step.code_action).to eq("puts 'ok'")
      end
    end

    context "with success vs error branches in apply_execution_result" do
      let(:response) do
        Smolagents::ChatMessage.assistant("```ruby\nx = 10\n```", tool_calls: nil)
      end

      before do
        allow(mock_model).to receive(:generate).and_return(response)
      end

      it "takes success branch when error is nil" do
        result = Smolagents::Executors::Executor::ExecutionResult.success(
          output: 10,
          logs: "Computed: 10",
          is_final_answer: true
        )
        allow(mock_executor).to receive(:execute).and_return(result)

        agent.execute_step(action_step)

        expect(action_step.observations).to eq("Computed: 10")
        expect(action_step.action_output).to eq(10)
        expect(action_step.is_final_answer).to be true
        expect(action_step.error).to be_nil
      end

      it "takes error branch when error is present" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "SyntaxError: bad",
          logs: "Partial logs"
        )
        allow(mock_executor).to receive(:execute).and_return(result)

        agent.execute_step(action_step)

        expect(action_step.error).to eq("SyntaxError: bad")
        expect(action_step.observations).to eq("Partial logs")
        expect(action_step.action_output).to be_nil
      end
    end
  end

  describe "integration tests" do
    let(:action_step) do
      Smolagents::ActionStepBuilder.new(step_number: 0)
    end

    it "handles complete flow from generation to execution" do
      response = Smolagents::ChatMessage.assistant(
        "Searching:\n```ruby\nresults = search(query: 'Ruby')\nfinal_answer(answer: results)\n```",
        tool_calls: nil,
        token_usage: Smolagents::Types::TokenUsage.new(input_tokens: 20, output_tokens: 10)
      )
      allow(mock_model).to receive(:generate).and_return(response)

      execution_result = Smolagents::Executors::Executor::ExecutionResult.success(
        output: "Ruby 3.0 released",
        logs: "Searched...\n",
        is_final_answer: true
      )
      allow(mock_executor).to receive(:execute).and_return(execution_result)

      agent.execute_step(action_step)

      expect(action_step.model_output_message.content).to include("search(query: 'Ruby')")
      expect(action_step.token_usage.input_tokens).to eq(20)
      expect(action_step.code_action).to eq("results = search(query: 'Ruby')\nfinal_answer(answer: results)")
      expect(action_step.observations).to eq("Searched...\n")
      expect(action_step.action_output).to eq("Ruby 3.0 released")
      expect(action_step.is_final_answer).to be true
    end

    it "handles multiple sequential steps with state propagation" do
      # First step
      step1 = Smolagents::ActionStepBuilder.new(step_number: 0)
      response1 = Smolagents::ChatMessage.assistant("```ruby\nq = 'test'\n```", tool_calls: nil)
      allow(mock_model).to receive(:generate).and_return(response1)
      allow(mock_executor).to receive(:execute)
        .and_return(Smolagents::Executors::Executor::ExecutionResult.success(output: "ok", logs: ""))

      agent.execute_step(step1)
      expect(step1.code_action).to eq("q = 'test'")

      # Update state for second step
      agent.state = { "previous_result" => "ok" }

      # Second step
      step2 = Smolagents::ActionStepBuilder.new(step_number: 1)
      response2 = Smolagents::ChatMessage.assistant("```ruby\nfinal_answer(answer: result)\n```", tool_calls: nil)
      allow(mock_model).to receive(:generate).and_return(response2)
      allow(mock_executor).to receive(:send_variables).with(agent.state)

      agent.execute_step(step2)

      expect(mock_executor).to have_received(:send_variables).with(agent.state)
      expect(step2.code_action).to eq("final_answer(answer: result)")
    end
  end

  describe "edge cases" do
    let(:action_step) do
      Smolagents::ActionStepBuilder.new(step_number: 0)
    end

    context "with very long code blocks" do
      it "handles large code snippets" do
        large_code = "x = 1\n" * 500
        response = Smolagents::ChatMessage.assistant(
          "```ruby\n#{large_code}```",
          tool_calls: nil
        )
        allow(mock_model).to receive(:generate).and_return(response)
        allow(mock_executor).to receive(:execute)
          .and_return(Smolagents::Executors::Executor::ExecutionResult.success(output: "ok"))

        agent.execute_step(action_step)

        expect(action_step.code_action.length).to be > 1000
      end
    end

    context "with special characters in code" do
      it "preserves special characters during extraction" do
        response = Smolagents::ChatMessage.assistant(
          "```ruby\nmsg = \"Hello, 'world'! \\\"test\\\"\"\nputs msg\n```",
          tool_calls: nil
        )
        allow(mock_model).to receive(:generate).and_return(response)
        allow(mock_executor).to receive(:execute)
          .and_return(Smolagents::Executors::Executor::ExecutionResult.success(output: "ok"))

        agent.execute_step(action_step)

        expect(action_step.code_action).to include("'world'")
      end
    end

    context "with whitespace variations" do
      it "handles indented code blocks" do
        response = Smolagents::ChatMessage.assistant(
          "```ruby\n  result = calculate()\n  puts result\n```",
          tool_calls: nil
        )
        allow(mock_model).to receive(:generate).and_return(response)
        allow(mock_executor).to receive(:execute)
          .and_return(Smolagents::Executors::Executor::ExecutionResult.success(output: "ok"))

        agent.execute_step(action_step)

        expect(action_step.code_action).to include("result = calculate()")
      end
    end

    context "with empty output" do
      it "handles empty execution output" do
        response = Smolagents::ChatMessage.assistant("```ruby\nputs 'done'\n```", tool_calls: nil)
        allow(mock_model).to receive(:generate).and_return(response)
        allow(mock_executor).to receive(:execute)
          .and_return(Smolagents::Executors::Executor::ExecutionResult.success(output: ""))

        agent.execute_step(action_step)

        expect(action_step.action_output).to eq("")
      end
    end

    context "with nil values in ExecutionResult" do
      it "handles nil output gracefully" do
        response = Smolagents::ChatMessage.assistant("```ruby\n# comment only\n```", tool_calls: nil)
        allow(mock_model).to receive(:generate).and_return(response)
        allow(mock_executor).to receive(:execute)
          .and_return(Smolagents::Executors::Executor::ExecutionResult.success(output: nil))

        agent.execute_step(action_step)

        expect(action_step.action_output).to be_nil
      end
    end
  end

  describe "private methods accessibility" do
    it "exposes private methods for testing via send" do
      action_step = Smolagents::ActionStepBuilder.new(step_number: 0)
      response = Smolagents::ChatMessage.assistant("```ruby\nputs 'test'\n```", tool_calls: nil)

      code = agent.send(:extract_code_from_response, action_step, response)

      expect(code).to eq("puts 'test'")
    end

    it "generates code response and captures token usage" do
      response = Smolagents::ChatMessage.assistant(
        "code",
        tool_calls: nil,
        token_usage: Smolagents::Types::TokenUsage.new(input_tokens: 5, output_tokens: 3)
      )
      allow(mock_model).to receive(:generate).and_return(response)

      action_step = Smolagents::ActionStepBuilder.new(step_number: 0)
      result = agent.send(:generate_code_response, action_step)

      expect(result).to eq(response)
      expect(action_step.token_usage.input_tokens).to eq(5)
    end
  end
end
