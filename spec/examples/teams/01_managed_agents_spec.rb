require "spec_helper"
require_relative "../../../examples/teams/01_managed_agents"

RSpec.describe "Example: Managed Agents", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "create_agent_with_helper (AgentBuilder DSL)" do
    it "creates parent agent with managed sub-agent" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      helper = mock_model { |m| m.queue_final_answer("helped") }

      agent = create_agent_with_helper(parent, helper)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "registers the managed agent as a tool" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      helper = mock_model { |m| m.queue_final_answer("helped") }

      agent = create_agent_with_helper(parent, helper)

      expect(agent.tools.keys).to include("researcher")
    end

    it "managed_agents hash contains ManagedAgentTool" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      helper = mock_model { |m| m.queue_final_answer("helped") }

      agent = create_agent_with_helper(parent, helper)

      expect(agent.managed_agents).to have_key("researcher")
      expect(agent.managed_agents["researcher"]).to be_a(Smolagents::ManagedAgentTool)
    end

    it "sub-agent has its own tools" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      helper = mock_model { |m| m.queue_final_answer("helped") }

      agent = create_agent_with_helper(parent, helper)

      sub_agent = agent.managed_agents["researcher"].agent
      expect(sub_agent.tools).to have_key("lookup")
    end
  end

  describe "create_agent_with_specialists (multiple managed agents)" do
    it "creates agent with multiple managed agents" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      researcher = mock_model { |m| m.queue_final_answer("researched") }
      writer = mock_model { |m| m.queue_final_answer("written") }

      agent = create_agent_with_specialists(parent, researcher, writer)

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.tools.keys).to include("researcher", "writer")
    end

    it "each managed agent has its own tools" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      researcher = mock_model { |m| m.queue_final_answer("r") }
      writer = mock_model { |m| m.queue_final_answer("w") }

      agent = create_agent_with_specialists(parent, researcher, writer)

      expect(agent.managed_agents["researcher"].agent.tools).to have_key("search")
      expect(agent.managed_agents["writer"].agent.tools).to have_key("format")
    end
  end

  describe "create_team_with_coordination (TeamBuilder)" do
    it "creates coordinator with managed sub-agent" do
      coordinator = mock_model { |m| m.queue_final_answer("done") }
      helper = mock_model { |m| m.queue_final_answer("helped") }

      team = create_team_with_coordination(coordinator, helper)

      expect(team).to be_a(Smolagents::Agents::Agent)
      expect(team.tools.keys).to include("researcher")
    end
  end

  describe "AgentBuilder.managed_agent DSL" do
    it "accepts symbol for as: parameter" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      child = mock_model { |m| m.queue_final_answer("child") }
      sub_agent = Smolagents.agent.model { child }.build

      agent = Smolagents.agent
                        .model { parent }
                        .managed_agent(sub_agent, as: :my_helper)
                        .build

      expect(agent.tools).to have_key("my_helper")
    end

    it "accepts string for as: parameter" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      child = mock_model { |m| m.queue_final_answer("child") }
      sub_agent = Smolagents.agent.model { child }.build

      agent = Smolagents.agent
                        .model { parent }
                        .managed_agent(sub_agent, as: "string_name")
                        .build

      expect(agent.tools).to have_key("string_name")
    end

    it "chains multiple managed_agent calls" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      child1 = mock_model { |m| m.queue_final_answer("a") }
      child2 = mock_model { |m| m.queue_final_answer("b") }

      agent1 = Smolagents.agent.model { child1 }.build
      agent2 = Smolagents.agent.model { child2 }.build

      agent = Smolagents.agent
                        .model { parent }
                        .managed_agent(agent1, as: :first)
                        .managed_agent(agent2, as: :second)
                        .build

      expect(agent.tools.keys).to include("first", "second")
    end

    it "accepts AgentBuilder (not just built agent)" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      child = mock_model { |m| m.queue_final_answer("child") }

      # Pass builder, not built agent
      sub_builder = Smolagents.agent.model { child }

      agent = Smolagents.agent
                        .model { parent }
                        .managed_agent(sub_builder, as: :lazy_helper)
                        .build

      expect(agent.tools).to have_key("lazy_helper")
    end
  end

  describe "ManagedAgentTool" do
    it "wraps agent as callable tool" do
      model = mock_model { |m| m.queue_final_answer("result") }
      agent = Smolagents.agent.model { model }.build

      tool = Smolagents::ManagedAgentTool.new(agent:, name: "helper")

      expect(tool.tool_name).to eq("helper")
      expect(tool.description).to include("final_answer")
    end

    it "has task as input parameter" do
      model = mock_model { |m| m.queue_final_answer("result") }
      agent = Smolagents.agent.model { model }.build

      tool = Smolagents::ManagedAgentTool.new(agent:, name: "worker")

      expect(tool.inputs).to have_key(:task)
      expect(tool.inputs[:task][:type]).to eq("string")
    end
  end

  # ===========================================================================
  # EVENT INTEGRATION
  # ===========================================================================
  #
  # Sub-agent lifecycle events enable observability into delegated work.
  # Use these patterns to track, log, and coordinate multi-agent workflows.
  #
  # NOTE: SubAgent events (SubAgentLaunched, SubAgentCompleted) are emitted
  # by the ManagedAgentTool. To receive them, connect the agent to an event
  # queue via `.connect_to(queue)`.

  describe "event integration" do
    let(:event_queue) { Thread::Queue.new }

    def drain_events
      events = []
      events << event_queue.pop until event_queue.empty?
      events
    end

    describe "event types overview" do
      it "SubAgentLaunched includes agent_name, task, and parent_id" do
        # SubAgentLaunched is emitted when a managed agent starts executing
        event = Smolagents::Events::SubAgentLaunched.create(
          agent_name: "researcher",
          task: "find Ruby version",
          parent_id: "parent-123"
        )

        expect(event.agent_name).to eq("researcher")
        expect(event.task).to eq("find Ruby version")
        expect(event.parent_id).to eq("parent-123")
        expect(event.id).to be_a(String) # Unique event ID for correlation
      end

      it "SubAgentCompleted includes outcome, output, duration, and step_count" do
        # SubAgentCompleted is emitted when a managed agent finishes
        event = Smolagents::Events::SubAgentCompleted.create(
          launch_id: "launch-456",
          agent_name: "researcher",
          outcome: :success,
          output: "Found Ruby 3.3",
          duration: 1.5,
          step_count: 3,
          token_usage: { input: 100, output: 50 }
        )

        expect(event.agent_name).to eq("researcher")
        expect(event.outcome).to eq(:success)
        expect(event.output).to eq("Found Ruby 3.3")
        expect(event.duration).to eq(1.5)
        expect(event.step_count).to eq(3)
        expect(event.token_usage).to eq({ input: 100, output: 50 })
        expect(event).to be_success
      end

      it "SubAgentCompleted has predicate methods for outcomes" do
        success = Smolagents::Events::SubAgentCompleted.create(
          launch_id: "1", agent_name: "a", outcome: :success
        )
        failure = Smolagents::Events::SubAgentCompleted.create(
          launch_id: "2", agent_name: "b", outcome: :failure
        )
        error = Smolagents::Events::SubAgentCompleted.create(
          launch_id: "3", agent_name: "c", outcome: :error, error: "timeout"
        )

        expect(success).to be_success
        expect(failure).to be_failure
        expect(error).to be_error
      end
    end

    describe "on_agents category subscription" do
      it "subscribes to all agent lifecycle events" do
        # on_agents is a convenience method that subscribes to:
        # :sub_agent_launched, :sub_agent_progress, :sub_agent_completed, :spawn_restricted
        # These events are emitted by ManagedAgentTools during sub-agent execution.

        # on_agents maps to SubAgentLaunched, SubAgentProgress,
        # SubAgentCompleted, and SpawnRestricted events
        parent = mock_model { |m| m.queue_final_answer("done") }
        agent = Smolagents.agent.model { parent }.build

        expect(agent).to respond_to(:on_agents)
      end
    end

    describe "step_completed events track tool execution" do
      it "emits step events that include managed agent tool calls" do
        parent = mock_model do |m|
          m.queue_tool_call(:helper, task: "do work")
          m.queue_final_answer("done")
        end
        child = mock_model { |m| m.queue_final_answer("helped") }

        agent = Smolagents.agent
                          .model { parent }
                          .managed_agent(
                            Smolagents.agent.model { child }.build,
                            as: :helper
                          )
                          .build

        agent.connect_to(event_queue)
        agent.run("Do something")
        events = drain_events

        # Step events are emitted for each execution step
        step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }
        expect(step_events).not_to be_empty

        # Each step has a step_number and outcome
        step_events.each do |step|
          expect(step.step_number).to be_a(Integer)
          expect(step.outcome).to be_a(Symbol)
        end
      end
    end

    describe "event-based result aggregation pattern" do
      it "shows how to aggregate sub-agent results via event tracking" do
        # This pattern demonstrates manual aggregation via tracker objects
        tracker = Class.new do
          attr_reader :launches, :completions

          def initialize
            @launches = []
            @completions = []
          end

          def track_launch(event)
            @launches << { agent: event.agent_name, task: event.task, time: Time.now }
          end

          def track_complete(event)
            @completions << { agent: event.agent_name, outcome: event.outcome, output: event.output }
          end
        end.new

        # Simulate events that would be emitted by ManagedAgentTool
        launch = Smolagents::Events::SubAgentLaunched.create(
          agent_name: "researcher", task: "find data"
        )
        complete = Smolagents::Events::SubAgentCompleted.create(
          launch_id: launch.id, agent_name: "researcher", outcome: :success, output: "findings"
        )

        tracker.track_launch(launch)
        tracker.track_complete(complete)

        expect(tracker.launches.size).to eq(1)
        expect(tracker.completions.size).to eq(1)
        expect(tracker.completions.first[:output]).to eq("findings")
      end
    end

    describe "task_completed event for overall completion" do
      it "fires when agent run completes" do
        parent = mock_model { |m| m.queue_final_answer("done") }
        agent = Smolagents.agent.model { parent }.build

        agent.connect_to(event_queue)
        agent.run("Simple task")
        events = drain_events

        task_events = events.select { |e| e.is_a?(Smolagents::Events::TaskLifecycle) && e.completed? }

        expect(task_events.size).to eq(1)
        expect(task_events.first.outcome).to eq(:success)
        expect(task_events.first.output).to eq("done")
      end
    end
  end
end
