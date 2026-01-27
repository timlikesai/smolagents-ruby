require "spec_helper"
require_relative "../../../examples/teams/02_team_building"

RSpec.describe "Example: Team Building", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "create_basic_team" do
    it "creates a team with coordinator and sub-agents" do
      coord_model = mock_model { |m| m.queue_final_answer("coordinated") }
      research_model = mock_model { |m| m.queue_final_answer("researched") }
      analyst_model = mock_model { |m| m.queue_final_answer("analyzed") }

      team = create_basic_team(coord_model, research_model, analyst_model)

      expect(team).to be_a(Smolagents::Agents::Agent)
    end

    it "team has sub-agents as tools" do
      coord_model = mock_model { |m| m.queue_final_answer("done") }
      research_model = mock_model { |m| m.queue_final_answer("r") }
      analyst_model = mock_model { |m| m.queue_final_answer("a") }

      team = create_basic_team(coord_model, research_model, analyst_model)

      expect(team.tools.keys).to include("researcher", "analyst")
    end
  end

  describe "create_team_with_instructions" do
    it "creates team with coordination instructions" do
      coord_model = mock_model { |m| m.queue_final_answer("done") }
      research_model = mock_model { |m| m.queue_final_answer("r") }
      writer_model = mock_model { |m| m.queue_final_answer("w") }

      team = create_team_with_instructions(coord_model, research_model, writer_model)

      expect(team).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_team_with_limits" do
    it "creates team with max_steps limit" do
      coord_model = mock_model { |m| m.queue_final_answer("done") }
      helper_model = mock_model { |m| m.queue_final_answer("helped") }

      team = create_team_with_limits(coord_model, helper_model)

      expect(team).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "TeamBuilder DSL" do
    it "Smolagents.team creates TeamBuilder" do
      builder = Smolagents.team

      expect(builder).to be_a(Smolagents::Builders::TeamBuilder)
    end

    it ".agent adds sub-agent to team" do
      coord_model = mock_model { |m| m.queue_final_answer("done") }
      sub_model = mock_model { |m| m.queue_final_answer("sub") }
      sub_agent = Smolagents.agent.model { sub_model }.build

      team = Smolagents.team
                       .model { coord_model }
                       .agent(sub_agent, as: "helper")
                       .build

      expect(team.tools).to have_key("helper")
    end

    it ".coordinate sets coordination instructions" do
      coord_model = mock_model { |m| m.queue_final_answer("done") }
      sub_model = mock_model { |m| m.queue_final_answer("sub") }
      sub_agent = Smolagents.agent.model { sub_model }.build

      team = Smolagents.team
                       .model { coord_model }
                       .agent(sub_agent, as: "worker")
                       .coordinate("Use worker for all tasks")
                       .build

      expect(team).to be_a(Smolagents::Agents::Agent)
    end

    it ".max_steps limits coordinator steps" do
      coord_model = mock_model { |m| m.queue_final_answer("done") }
      sub_model = mock_model { |m| m.queue_final_answer("sub") }
      sub_agent = Smolagents.agent.model { sub_model }.build

      team = Smolagents.team
                       .model { coord_model }
                       .agent(sub_agent, as: "worker")
                       .max_steps(5)
                       .build

      expect(team).to be_a(Smolagents::Agents::Agent)
    end

    it "model is shared with sub-agents without models" do
      shared_model = mock_model do |m|
        m.queue_final_answer("shared")
        m.queue_final_answer("done")
      end

      # Sub-agent without model
      sub_builder = Smolagents.agent

      team = Smolagents.team
                       .model { shared_model }
                       .agent(sub_builder, as: "worker")
                       .build

      expect(team).to be_a(Smolagents::Agents::Agent)
    end
  end

  # ===========================================================================
  # EVENT-BASED COORDINATION
  # ===========================================================================
  #
  # Events enable sophisticated multi-agent coordination patterns.
  # Use `.connect_to(queue)` to receive events via a Thread::Queue.
  # StepCompleted and TaskCompleted are emitted by the coordinator,
  # while SubAgent events are emitted by ManagedAgentTools.

  describe "multi-agent coordination via events" do
    let(:event_queue) { Thread::Queue.new }

    def drain_events
      events = []
      events << event_queue.pop until event_queue.empty?
      events
    end

    describe "tracking team progress via step events" do
      it "monitors coordinator steps when delegating to sub-agents" do
        coord_model = mock_model do |m|
          m.queue_tool_call(:researcher, task: "gather data")
          m.queue_final_answer("team complete")
        end
        research_model = mock_model { |m| m.queue_final_answer("data found") }

        team = Smolagents.team
                         .model { coord_model }
                         .agent(
                           Smolagents.agent.model { research_model }.build,
                           as: "researcher"
                         )
                         .build

        team.connect_to(event_queue)
        team.run("Complete research project")
        events = drain_events

        step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }

        # Coordinator emits step events for each execution cycle
        expect(step_events).not_to be_empty
        expect(step_events.first.step_number).to eq(1)
      end
    end

    describe "task completion tracking" do
      it "emits task_complete when team finishes" do
        coord_model = mock_model { |m| m.queue_final_answer("done") }
        worker_model = mock_model { |m| m.queue_final_answer("worked") }

        # TeamBuilder requires at least one sub-agent
        team = Smolagents.team
                         .model { coord_model }
                         .agent(Smolagents.agent.model { worker_model }.build, as: "worker")
                         .build

        team.connect_to(event_queue)
        team.run("Simple task")
        events = drain_events

        task_events = events.select { |e| e.is_a?(Smolagents::Events::TaskCompleted) }

        expect(task_events.size).to eq(1)
        expect(task_events.first.outcome).to eq(:success)
      end
    end

    describe "on_agents category subscription" do
      it "is available for subscribing to agent lifecycle events" do
        coord_model = mock_model { |m| m.queue_final_answer("complete") }
        worker_model = mock_model { |m| m.queue_final_answer("worked") }

        # TeamBuilder requires at least one sub-agent
        team = Smolagents.team
                         .model { coord_model }
                         .agent(Smolagents.agent.model { worker_model }.build, as: "worker")
                         .build

        # on_agents subscribes to: agent_launch, agent_progress, agent_complete, spawn_restricted
        # These events are emitted by ManagedAgentTool during sub-agent execution
        expect(team).to respond_to(:on_agents)
      end
    end

    describe "step-level progress tracking" do
      it "tracks coordinator steps with :step_complete" do
        coord_model = mock_model do |m|
          m.queue_tool_call(:helper, task: "step 1 work")
          m.queue_final_answer("done")
        end
        helper_model = mock_model { |m| m.queue_final_answer("helped") }

        team = Smolagents.team
                         .model { coord_model }
                         .agent(
                           Smolagents.agent.model { helper_model }.build,
                           as: "helper"
                         )
                         .build

        team.connect_to(event_queue)
        team.run("Multi-step task")
        events = drain_events

        step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }
        steps = step_events.map(&:step_number)

        # Coordinator emits step events for each execution cycle
        expect(steps).not_to be_empty
        expect(steps).to eq(steps.sort) # Steps are sequential
      end
    end

    describe "error handling in teams" do
      it "captures step events even when sub-agents fail" do
        # When a sub-agent fails, the coordinator continues and can handle it
        coord_model = mock_model do |m|
          m.queue_tool_call(:unreliable, task: "might fail")
          m.queue_final_answer("handled failure")
        end
        # Sub-agent will hit max steps without answering (failure state)
        failing_model = mock_model { |m| m.queue_code_action("x = 1") }

        team = Smolagents.team
                         .model { coord_model }
                         .agent(
                           Smolagents.agent.model { failing_model }.max_steps(1).build,
                           as: "unreliable"
                         )
                         .build

        team.connect_to(event_queue)
        team.run("Try unreliable task")
        events = drain_events

        # Step events are emitted even when sub-agents have issues
        step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }
        expect(step_events).not_to be_empty
      end
    end
  end

  # ===========================================================================
  # EVENT-BASED ORCHESTRATION PATTERNS
  # ===========================================================================
  #
  # These patterns demonstrate how to build event tracking for multi-agent
  # systems. The tracker/aggregator pattern is used for collecting and
  # processing sub-agent results.

  describe "event-based orchestration patterns" do
    describe "tracker pattern for sub-agent coordination" do
      it "demonstrates aggregating sub-agent results via tracker objects" do
        # The tracker pattern - used in production for collecting sub-agent results
        tracker = Class.new do
          attr_reader :launches, :completions, :results

          def initialize
            @launches = []
            @completions = []
            @results = {}
            @mutex = Mutex.new
          end

          def track_launch(event)
            @mutex.synchronize do
              @launches << { agent: event.agent_name, task: event.task, time: Time.now }
            end
          end

          def track_complete(event)
            @mutex.synchronize do
              @completions << { agent: event.agent_name, outcome: event.outcome }
              @results[event.agent_name] = event.output
            end
          end

          def success_rate
            return 0.0 if @completions.empty?

            successes = @completions.count { |c| c[:outcome] == :success }
            successes.to_f / @completions.size
          end
        end.new

        # Simulate events from a multi-agent workflow
        researchers = %w[broad_searcher deep_diver academic]

        researchers.each do |name|
          launch = Smolagents::Events::SubAgentLaunched.create(
            agent_name: name, task: "research topic"
          )
          complete = Smolagents::Events::SubAgentCompleted.create(
            launch_id: launch.id, agent_name: name,
            outcome: :success, output: "#{name} findings"
          )

          tracker.track_launch(launch)
          tracker.track_complete(complete)
        end

        expect(tracker.launches.size).to eq(3)
        expect(tracker.completions.size).to eq(3)
        expect(tracker.results.keys).to match_array(researchers)
        expect(tracker.success_rate).to eq(1.0)
      end
    end

    describe "sequential pipeline via step events" do
      it "verifies coordinator executes stages in order" do
        coord_model = mock_model do |m|
          m.queue_tool_call(:stage1, task: "extract")
          m.queue_final_answer("pipeline complete")
        end
        stage1_model = mock_model { |m| m.queue_final_answer("extracted") }

        event_queue = Thread::Queue.new
        team = Smolagents.team
                         .model { coord_model }
                         .agent(Smolagents.agent.model { stage1_model }.build, as: "stage1")
                         .build

        team.connect_to(event_queue)
        team.run("Run ETL pipeline")

        events = []
        events << event_queue.pop until event_queue.empty?

        step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }

        # Steps execute sequentially
        step_numbers = step_events.map(&:step_number)
        expect(step_numbers).to eq(step_numbers.sort)
        expect(step_numbers).not_to be_empty
      end
    end

    describe "combining step and task events" do
      it "provides comprehensive execution visibility" do
        coord_model = mock_model { |m| m.queue_final_answer("complete") }
        worker_model = mock_model { |m| m.queue_final_answer("done") }

        event_queue = Thread::Queue.new
        team = Smolagents.team
                         .model { coord_model }
                         .agent(
                           Smolagents.agent.model { worker_model }.build,
                           as: "worker"
                         )
                         .build

        team.connect_to(event_queue)
        team.run("Observable task")

        events = []
        events << event_queue.pop until event_queue.empty?

        # Events provide a complete trace of execution
        step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }
        task_events = events.select { |e| e.is_a?(Smolagents::Events::TaskCompleted) }

        expect(step_events).not_to be_empty
        expect(task_events.size).to eq(1)

        # Task event contains final outcome and statistics
        task = task_events.first
        expect(task.outcome).to eq(:success)
        expect(task.steps_taken).to eq(step_events.size)
      end
    end
  end
end
