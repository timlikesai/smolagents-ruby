RSpec.describe Smolagents::ManagedAgentTool do
  let(:mock_agent_class) do
    Class.new do
      attr_reader :tools

      def initialize
        @tools = { "search" => Object.new, "calculator" => Object.new }
      end

      def run(_prompt, _reset: true)
        Smolagents::RunResult.new(
          output: "Agent completed task",
          state: :success,
          steps: [],
          token_usage: nil,
          timing: nil
        )
      end

      def self.name
        "MockAgent"
      end
    end
  end

  let(:mock_agent) { mock_agent_class.new }
  let(:managed_tool) { described_class.new(agent: mock_agent) }

  describe "#initialize" do
    it "creates a tool from an agent" do
      expect(managed_tool).to be_a(Smolagents::Tool)
    end

    it "derives tool name from agent class name" do
      expect(managed_tool.tool_name).to eq("mock_agent")
    end

    it "allows custom tool name" do
      custom_tool = described_class.new(agent: mock_agent, name: "custom_name")
      expect(custom_tool.tool_name).to eq("custom_name")
    end

    it "derives description from agent's tools" do
      expect(managed_tool.description).to include("search")
      expect(managed_tool.description).to include("calculator")
    end

    it "allows custom description" do
      custom_tool = described_class.new(agent: mock_agent, description: "Custom description")
      expect(custom_tool.description).to eq("Custom description")
    end
  end

  describe "tool attributes" do
    it "has correct tool_name" do
      expect(managed_tool.tool_name).to eq("mock_agent")
      expect(managed_tool.name).to eq("mock_agent")
    end

    it "has correct description" do
      expect(managed_tool.description).to be_a(String)
      expect(managed_tool.description).to include("specialized agent")
    end

    it "has correct inputs" do
      expect(managed_tool.inputs).to be_a(Hash)
      expect(managed_tool.inputs).to have_key("task")
      expect(managed_tool.inputs["task"][:type]).to eq("string")
      expect(managed_tool.inputs["task"][:description]).to include("mock_agent")
    end

    it "has correct output_type" do
      expect(managed_tool.output_type).to eq("string")
    end

    it "has nil output_schema" do
      expect(managed_tool.output_schema).to be_nil
    end
  end

  describe "#to_h" do
    it "converts to hash with dynamic attributes" do
      hash = managed_tool.to_h
      expect(hash[:name]).to eq("mock_agent")
      expect(hash[:description]).to be_a(String)
      expect(hash[:inputs]).to have_key("task")
      expect(hash[:output_type]).to eq("string")
    end
  end

  describe "#format_for(:code)" do
    it "generates compact prompt with dynamic attributes" do
      prompt = managed_tool.format_for(:code)
      expect(prompt).to include("mock_agent(")
      expect(prompt).to include("task:")
      expect(prompt).to include("The task to assign")
    end
  end

  describe "#format_for(:managed_agent)" do
    it "generates managed agent prompt with agent name" do
      prompt = managed_tool.format_for(:managed_agent)
      expect(prompt).to include("mock_agent:")
      expect(prompt.downcase).to include("delegate tasks")
      expect(prompt).to include("mock_agent")
    end
  end

  describe "#execute" do
    let(:success_result) do
      Smolagents::RunResult.new(
        output: "Success",
        state: :success,
        steps: [],
        token_usage: nil,
        timing: nil
      )
    end

    it "delegates to the wrapped agent" do
      allow(mock_agent).to receive(:run).and_return(success_result)

      result = managed_tool.execute(task: "Test task")

      expect(result).to eq("Success")
      expect(mock_agent).to have_received(:run).with(anything, reset: true)
    end

    it "handles agent failures" do
      allow(mock_agent).to receive(:run).and_return(
        Smolagents::RunResult.new(
          output: nil,
          state: :error,
          steps: [],
          token_usage: nil,
          timing: nil
        )
      )

      result = managed_tool.execute(task: "Test task")
      expect(result).to include("failed")
      expect(result).to include("error")
    end

    it "includes agent name in the prompt" do
      allow(mock_agent).to receive(:run).and_return(success_result)

      managed_tool.execute(task: "Test task")

      expect(mock_agent).to have_received(:run).with(
        a_string_including("mock_agent"),
        reset: true
      )
    end

    it "includes the task in the prompt" do
      allow(mock_agent).to receive(:run).and_return(success_result)

      managed_tool.execute(task: "Specific test task")

      expect(mock_agent).to have_received(:run).with(
        a_string_including("Specific test task"),
        reset: true
      )
    end
  end

  describe "#call" do
    it "works like a normal tool" do
      result = managed_tool.call(task: "Test task")
      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.tool_name).to eq("mock_agent")
    end

    it "includes metadata" do
      result = managed_tool.call(task: "Test task")
      expect(result.metadata[:inputs]).to eq({ task: "Test task" })
      expect(result.metadata[:output_type]).to eq("string")
    end
  end

  describe "multiple instances" do
    it "maintains independent attributes" do
      tool1 = described_class.new(agent: mock_agent, name: "agent1")
      tool2 = described_class.new(agent: mock_agent, name: "agent2")

      expect(tool1.tool_name).to eq("agent1")
      expect(tool2.tool_name).to eq("agent2")
      expect(tool1.inputs["task"][:description]).to include("agent1")
      expect(tool2.inputs["task"][:description]).to include("agent2")
    end

    it "does not share state between instances" do
      tool1 = described_class.new(agent: mock_agent, name: "first")
      expect(tool1.tool_name).to eq("first")

      tool2 = described_class.new(agent: mock_agent, name: "second")
      expect(tool2.tool_name).to eq("second")

      expect(tool1.tool_name).to eq("first")
    end
  end

  describe "Fiber execution" do
    let(:fiber_agent_class) do
      Class.new do
        attr_reader :tools

        def initialize
          @tools = { "search" => Object.new }
        end

        def run(_prompt, reset: true) # rubocop:disable Lint/UnusedMethodArgument
          Smolagents::RunResult.new(
            output: "Sync result",
            state: :success,
            steps: [],
            token_usage: nil,
            timing: nil
          )
        end

        def run_fiber(_prompt, reset: true) # rubocop:disable Lint/UnusedMethodArgument
          Fiber.new do
            Smolagents::Concerns::ReActLoop::Control::FiberControl.set_fiber_context(true)
            # Yield one step then final result
            Fiber.yield(Smolagents::Types::ActionStep.new(
                          step_number: 1,
                          observations: "Working on it"
                        ))
            Smolagents::Types::RunResult.new(
              output: "Fiber result",
              state: :success,
              steps: [],
              token_usage: nil,
              timing: nil
            )
          ensure
            Smolagents::Concerns::ReActLoop::Control::FiberControl.set_fiber_context(false)
          end
        end

        def self.name
          "FiberAgent"
        end
      end
    end

    let(:fiber_agent) { fiber_agent_class.new }
    let(:fiber_tool) { described_class.new(agent: fiber_agent, name: "fiber_agent") }

    describe "#fiber_context?" do
      it "returns false when thread-local not set" do
        clear_fiber_context
        expect(fiber_tool.send(:fiber_context?)).to be false
      end

      it "returns true when thread-local is set" do
        set_fiber_context(true)
        expect(fiber_tool.send(:fiber_context?)).to be true
      ensure
        clear_fiber_context
      end
    end

    describe "#execute in sync context" do
      it "uses synchronous execution when not in Fiber context" do
        clear_fiber_context
        result = fiber_tool.execute(task: "Test task")
        expect(result).to eq("Sync result")
      end
    end

    describe "#execute in Fiber context" do
      it "uses Fiber execution when in Fiber context" do
        set_fiber_context(true)
        result = fiber_tool.execute(task: "Test task")
        expect(result).to eq("Fiber result")
      ensure
        clear_fiber_context
      end
    end

    describe "control request bubbling" do
      let(:requesting_agent_class) do
        Class.new do
          attr_reader :tools

          def initialize
            @tools = {}
          end

          def run(_prompt, reset: true) # rubocop:disable Lint/UnusedMethodArgument
            Smolagents::Types::RunResult.new(
              output: "Sync fallback",
              state: :success,
              steps: [],
              token_usage: nil,
              timing: nil
            )
          end

          def run_fiber(_prompt, reset: true) # rubocop:disable Lint/UnusedMethodArgument
            Fiber.new do
              Smolagents::Concerns::ReActLoop::Control::FiberControl.set_fiber_context(true)
              # Yield a control request
              request = Smolagents::Types::ControlRequests::UserInput.create(
                prompt: "What file should I read?"
              )
              response = Fiber.yield(request)
              Smolagents::Types::RunResult.new(
                output: "Read file: #{response.value}",
                state: :success,
                steps: [],
                token_usage: nil,
                timing: nil
              )
            ensure
              Smolagents::Concerns::ReActLoop::Control::FiberControl.set_fiber_context(false)
            end
          end

          def self.name
            "RequestingAgent"
          end
        end
      end

      let(:requesting_agent) { requesting_agent_class.new }
      let(:requesting_tool) { described_class.new(agent: requesting_agent, name: "requester") }

      it "wraps sub-agent requests as SubAgentQuery" do
        # Start execution in a parent Fiber that simulates the run_fiber context
        parent_fiber = Fiber.new do
          set_fiber_context(true)
          requesting_tool.execute(task: "Read a file")
        ensure
          clear_fiber_context
        end

        # First resume starts the fiber and should yield the wrapped request
        result = parent_fiber.resume
        expect(result).to be_a(Smolagents::Types::ControlRequests::SubAgentQuery)
        expect(result.agent_name).to eq("requester")
        expect(result.query).to eq("What file should I read?")
        expect(result.context[:original_id]).to be_a(String)

        # Respond and continue
        response = Smolagents::Types::ControlRequests::Response.respond(
          request_id: result.id,
          value: "config.yml"
        )
        final = parent_fiber.resume(response)
        expect(final).to eq("Read file: config.yml")
      end
    end
  end

  describe "DSL configuration" do
    let(:custom_subclass) do
      Class.new(described_class) do
        configure do
          name "researcher"
          description "Searches and summarizes findings"
          prompt_template <<~PROMPT
            You are a research specialist called '%<name>s'.
            Your task: %<task>s
          PROMPT
        end
      end
    end

    it "applies class-level name configuration" do
      tool = custom_subclass.new(agent: mock_agent)
      expect(tool.tool_name).to eq("researcher")
    end

    it "applies class-level description configuration" do
      tool = custom_subclass.new(agent: mock_agent)
      expect(tool.description).to eq("Searches and summarizes findings")
    end

    it "applies class-level prompt_template configuration" do
      tool = custom_subclass.new(agent: mock_agent)
      expect(tool.prompt_template).to include("research specialist")
    end

    it "allows instance override of class config" do
      tool = custom_subclass.new(agent: mock_agent, name: "custom_name")
      expect(tool.tool_name).to eq("custom_name")
    end

    it "inherits parent configuration" do
      child_class = Class.new(custom_subclass)
      tool = child_class.new(agent: mock_agent)
      expect(tool.tool_name).to eq("researcher")
    end

    it "child can override parent configuration" do
      child_class = Class.new(custom_subclass) do
        configure do
          name "analyst"
        end
      end
      tool = child_class.new(agent: mock_agent)
      expect(tool.tool_name).to eq("analyst")
    end

    it "falls back to derived name when no configuration" do
      tool = described_class.new(agent: mock_agent)
      expect(tool.tool_name).to eq("mock_agent")
    end
  end
end
