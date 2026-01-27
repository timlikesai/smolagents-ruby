require "spec_helper"
require_relative "../../../experiments/multi_model_agents/05_research_swarm"

RSpec.describe "Experiment: Research Swarm", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "ResearchAggregator" do
    let(:aggregator) { Experiments::ResearchSwarm::ResearchAggregator.new }

    it "stores research findings by researcher name" do
      aggregator.add("broad", "Found diverse sources")
      aggregator.add("deep", "Detailed analysis")

      expect(aggregator.results.keys).to contain_exactly("broad", "deep")
    end

    it "tracks timestamps and word counts" do
      aggregator.add("researcher", "These are five words here")

      result = aggregator.results["researcher"]
      expect(result[:word_count]).to eq(5)
      expect(result[:timestamp]).to be_a(Time)
    end

    it "generates combined summary" do
      aggregator.add("broad", "Broad findings")
      aggregator.add("deep", "Deep findings")

      summary = aggregator.combined_summary

      expect(summary).to include("## broad")
      expect(summary).to include("## deep")
      expect(summary).to include("Broad findings")
    end

    it "is thread-safe" do
      threads = Array.new(10) do |i|
        Thread.new { aggregator.add("researcher_#{i}", "Findings #{i}") }
      end
      threads.each(&:join)

      expect(aggregator.results.keys.size).to eq(10)
    end
  end

  describe "SwarmTracker" do
    let(:tracker) { Experiments::ResearchSwarm::SwarmTracker.new }

    it "tracks agent launches" do
      event = double(agent_name: "broad", task: "research")

      tracker.track_launch(event)

      expect(tracker.launches.size).to eq(1)
      expect(tracker.launches.first[:agent]).to eq("broad")
    end

    it "tracks agent completions" do
      event = double(agent_name: "broad", outcome: :success, output: "findings")

      tracker.track_complete(event)

      expect(tracker.completions.size).to eq(1)
      expect(tracker.completions.first[:outcome]).to eq(:success)
    end

    it "tracks errors" do
      event = double(
        error_class: "NetworkError",
        error_message: "Connection failed",
        recoverable: true
      )

      tracker.track_error(event)

      expect(tracker.errors.size).to eq(1)
      expect(tracker.errors.first[:recoverable]).to be true
    end

    it "calculates success rate" do
      tracker.track_complete(double(agent_name: "a", outcome: :success, output: ""))
      tracker.track_complete(double(agent_name: "b", outcome: :success, output: ""))
      tracker.track_complete(double(agent_name: "c", outcome: :failure, output: ""))

      summary = tracker.summary

      expect(summary[:success_rate]).to be_within(0.01).of(0.67)
    end
  end

  describe "Researchers module" do
    it "creates broad_searcher with web_search tool" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = Experiments::ResearchSwarm::Researchers.broad_searcher(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.tools.keys).to include("web_search")
    end

    it "creates deep_diver with scrape and follow tools" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = Experiments::ResearchSwarm::Researchers.deep_diver(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.tools.keys).to include("scrape_page", "follow_links")
    end

    it "creates academic_searcher with arxiv and scholar tools" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = Experiments::ResearchSwarm::Researchers.academic_searcher(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.tools.keys).to include("arxiv_search", "scholar_search")
    end
  end

  describe ".build_swarm" do
    it "creates a team with three researcher sub-agents" do
      coordinator = mock_model { |m| m.queue_final_answer("done") }
      researcher = mock_model { |m| m.queue_final_answer("found") }

      result = Experiments::ResearchSwarm.build_swarm(
        coordinator_model: coordinator,
        researcher_model: researcher
      )

      expect(result[:team]).to be_a(Smolagents::Agents::Agent)
      expect(result[:team].tools.keys).to include(
        "broad_researcher",
        "deep_researcher",
        "academic_researcher"
      )
    end

    it "includes tracker and aggregator" do
      coordinator = mock_model { |m| m.queue_final_answer("done") }
      researcher = mock_model { |m| m.queue_final_answer("found") }

      result = Experiments::ResearchSwarm.build_swarm(
        coordinator_model: coordinator,
        researcher_model: researcher
      )

      expect(result[:tracker]).to be_a(Experiments::ResearchSwarm::SwarmTracker)
      expect(result[:aggregator]).to be_a(Experiments::ResearchSwarm::ResearchAggregator)
    end
  end

  describe ".build_for_testing" do
    it "creates team with individual mock models for each researcher" do
      result = Experiments::ResearchSwarm.build_for_testing(
        coordinator_responses: ["<code>\nfinal_answer(answer: \"synthesized\")\n</code>"],
        researcher_responses: {
          broad: ["<code>\nfinal_answer(answer: \"broad result\")\n</code>"],
          deep: ["<code>\nfinal_answer(answer: \"deep result\")\n</code>"],
          academic: ["<code>\nfinal_answer(answer: \"academic result\")\n</code>"]
        }
      )

      expect(result[:team]).to be_a(Smolagents::Agents::Agent)
      expect(result[:models][:coordinator]).to be_a(Smolagents::Testing::MockModel)
      expect(result[:models][:broad]).to be_a(Smolagents::Testing::MockModel)
      expect(result[:models][:deep]).to be_a(Smolagents::Testing::MockModel)
      expect(result[:models][:academic]).to be_a(Smolagents::Testing::MockModel)
    end

    it "provides tracker and aggregator for verification" do
      result = Experiments::ResearchSwarm.build_for_testing(
        coordinator_responses: ["<code>\nfinal_answer(answer: \"done\")\n</code>"],
        researcher_responses: {}
      )

      expect(result[:tracker]).to be_a(Experiments::ResearchSwarm::SwarmTracker)
      expect(result[:aggregator]).to be_a(Experiments::ResearchSwarm::ResearchAggregator)
    end
  end

  describe "swarm execution with mocks" do
    it "coordinator can complete without calling sub-agents" do
      result = Experiments::ResearchSwarm.build_for_testing(
        coordinator_responses: ["<code>\nfinal_answer(answer: \"direct answer\")\n</code>"],
        researcher_responses: {}
      )

      run_result = result[:team].run("Simple question")

      expect(run_result.output).to eq("direct answer")
    end
  end

  describe "event emission" do
    let(:event_queue) { Thread::Queue.new }

    def drain_events
      events = []
      events << event_queue.pop until event_queue.empty?
      events
    end

    it "emits step_complete and task_complete events" do
      result = Experiments::ResearchSwarm.build_for_testing(
        coordinator_responses: ["<code>\nfinal_answer(answer: \"done\")\n</code>"],
        researcher_responses: {}
      )

      result[:team].connect_to(event_queue)
      result[:team].run("Test research")
      events = drain_events

      step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }
      task_events = events.select { |e| e.is_a?(Smolagents::Events::TaskCompleted) }

      expect(step_events).not_to be_empty
      expect(task_events.size).to eq(1)
      expect(task_events.first.outcome).to eq(:success)
    end

    it "tracks events via registered handlers" do
      result = Experiments::ResearchSwarm.build_for_testing(
        coordinator_responses: ["<code>\nfinal_answer(answer: \"done\")\n</code>"],
        researcher_responses: {}
      )

      result[:team].connect_to(event_queue)
      result[:team].run("Test research")
      events = drain_events

      # Consume events to trigger registered handlers
      events.each { |e| result[:team].consume(e) }

      # Tracker should have no launches since no sub-agents were called
      expect(result[:tracker].launches).to be_empty
    end

    it "emits step events when coordinator calls sub-agent tools" do
      result = Experiments::ResearchSwarm.build_for_testing(
        coordinator_responses: [
          "<code>\nbroad_researcher(task: \"Find broad info\")\n</code>",
          "<code>\nfinal_answer(answer: \"Synthesized result\")\n</code>"
        ],
        researcher_responses: {
          broad: ["<code>\nfinal_answer(answer: \"broad findings\")\n</code>"]
        }
      )

      result[:team].connect_to(event_queue)
      result[:team].run("Research topic")
      events = drain_events

      # Verify step events are emitted for each step
      step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }

      # Should have multiple steps: tool call + final answer
      expect(step_events.size).to be >= 2
    end

    it "tracker works with manually created events" do
      tracker = Experiments::ResearchSwarm::SwarmTracker.new

      # Simulate what the event handlers would receive
      launch_event = Smolagents::Events::SubAgentLaunched.create(
        agent_name: "broad_researcher",
        task: "Search broadly"
      )
      complete_event = Smolagents::Events::SubAgentCompleted.create(
        launch_id: launch_event.id,
        agent_name: "broad_researcher",
        outcome: :success,
        output: "results"
      )

      tracker.track_launch(launch_event)
      tracker.track_complete(complete_event)

      summary = tracker.summary

      expect(summary[:launched]).to eq(1)
      expect(summary[:completed]).to eq(1)
      expect(summary[:errors]).to eq(0)
      expect(summary[:success_rate]).to eq(1.0)
    end
  end
end
