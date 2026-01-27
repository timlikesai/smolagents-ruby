# Experiment: Research Swarm
#
# Parallel research agents with different strategies, coordinated by a synthesizer.
# Demonstrates multi-agent orchestration and result aggregation.
#
# Architecture:
#   ┌─────────────────────────────────┐
#   │         Coordinator             │ ← Fast model (orchestration)
#   └───────────┬─────────────────────┘
#               │ parallel dispatch
#   ┌───────────┼───────────┬─────────┐
#   │           │           │         │
#   ▼           ▼           ▼         │
# Broad      Deep       Academic      │
# Search     Dive       Papers        │
#   │           │           │         │
#   └───────────┼───────────┘         │
#               ▼                     │
#         Synthesizer ◄───────────────┘
#         (Big model)
#
# Run: ruby experiments/multi_model_agents/05_research_swarm.rb
# Test: bundle exec rspec spec/experiments/multi_model_agents/05_research_swarm_spec.rb

require_relative "../../lib/smolagents"

module Experiments
  module ResearchSwarm
    # Infrastructure endpoints (same as tiered reasoning)
    LLAMA_ULTRA = "https://llama-cpp-ultra.reverse-bull.ts.net/v1".freeze
    MACBOOK_PRO = "http://macbook-pro-m4.reverse-bull.ts.net:1234/v1".freeze

    # Research result aggregator
    class ResearchAggregator
      attr_reader :results

      def initialize
        @results = {}
        @mutex = Mutex.new
      end

      def add(researcher_name, findings)
        @mutex.synchronize do
          @results[researcher_name] = {
            findings:,
            timestamp: Time.now,
            word_count: findings.to_s.split.size
          }
        end
      end

      def all_findings
        @mutex.synchronize { @results.dup }
      end

      def combined_summary
        @results.map { |name, data| "## #{name}\n#{data[:findings]}" }.join("\n\n")
      end
    end

    # Event tracker for swarm coordination
    class SwarmTracker
      attr_reader :launches, :completions, :errors

      def initialize
        @launches = []
        @completions = []
        @errors = []
      end

      def track_launch(event)
        @launches << { agent: event.agent_name, task: event.task, time: Time.now }
      end

      def track_complete(event)
        @completions << {
          agent: event.agent_name,
          outcome: event.outcome,
          output_size: event.output.to_s.size
        }
      end

      def track_error(event)
        @errors << { class: event.error_class, message: event.error_message, recoverable: event.recoverable }
      end

      def summary
        {
          launched: @launches.size,
          completed: @completions.size,
          errors: @errors.size,
          success_rate: if @completions.empty?
                          0
                        else
                          @completions.count do |c|
                            c[:outcome] == :success
                          end.to_f / @completions.size
                        end
        }
      end
    end

    # Build individual researcher agents
    module Researchers
      def self.broad_searcher(model)
        Smolagents.agent
                  .model { model }
                  .tool(:web_search, "Search the web broadly", query: String) do |query:|
                    "Web results for '#{query}': [Result 1] [Result 2] [Result 3]"
        end
                 .instructions(<<~INST)
                   You are a broad research agent.
                   - Search for diverse sources and perspectives
                   - Prioritize breadth over depth
                   - Capture key themes and trends
                   - Return a summary of main findings
                 INST
                 .max_steps(5)
                 .build
      end

      def self.deep_diver(model)
        Smolagents.agent
                  .model { model }
                  .tool(:scrape_page, "Scrape a web page deeply", url: String) do |url:|
                    "Deep content from #{url}: [Detailed analysis...]"
        end
                 .tool(:follow_links, "Follow related links", base_url: String) do |base_url:|
                   "Related pages from #{base_url}: [Link 1] [Link 2]"
                 end
                 .instructions(<<~INST)
                   You are a deep research agent.
                   - Go deep on primary sources
                   - Follow citations and references
                   - Extract detailed information
                   - Verify claims where possible
                 INST
                 .max_steps(8)
                 .build
      end

      def self.academic_searcher(model)
        Smolagents.agent
                  .model { model }
                  .tool(:arxiv_search, "Search academic papers", topic: String) do |topic:|
                    "ArXiv papers on '#{topic}': [Paper 1: ...] [Paper 2: ...]"
        end
                 .tool(:scholar_search, "Search Google Scholar", query: String) do |query:|
                   "Scholar results for '#{query}': [Citation 1] [Citation 2]"
                 end
                 .instructions(<<~INST)
                   You are an academic research agent.
                   - Focus on peer-reviewed sources
                   - Track citations and impact
                   - Note methodology and limitations
                   - Summarize key findings with proper attribution
                 INST
                 .max_steps(5)
                 .build
      end
    end

    # Build the research swarm
    #
    # @param coordinator_model [Model] Model for coordination
    # @param researcher_model [Model] Model for individual researchers
    # @param synthesizer_model [Model] Model for final synthesis (can be larger)
    # @return [Hash] { team:, tracker:, aggregator: }
    def self.build_swarm(coordinator_model:, researcher_model:, synthesizer_model: nil)
      tracker = SwarmTracker.new
      aggregator = ResearchAggregator.new
      synthesizer_model || researcher_model

      # Create the researcher agents
      broad = Researchers.broad_searcher(researcher_model)
      deep = Researchers.deep_diver(researcher_model)
      academic = Researchers.academic_searcher(researcher_model)

      # Build the coordinated team
      team = Smolagents.team
                       .model { coordinator_model }
                       .agent(broad, as: "broad_researcher")
                       .agent(deep, as: "deep_researcher")
                       .agent(academic, as: "academic_researcher")
                       .coordinate(<<~COORD)
                         You coordinate a research swarm. For any research task:

                         1. DISPATCH: Send the task to ALL three researchers in parallel:
                            - broad_researcher: Get diverse perspectives
                            - deep_researcher: Go deep on primary sources
                            - academic_researcher: Find scholarly sources

                         2. COLLECT: Gather results from all researchers

                         3. SYNTHESIZE: Combine findings into a coherent summary that:
                            - Identifies common themes across sources
                            - Highlights unique insights from each approach
                            - Notes any contradictions or gaps
                            - Provides actionable conclusions
                       COORD
                       .max_steps(15)
                       .on(:agent_launch) { |e| tracker.track_launch(e) }
                       .on(:agent_complete) do |e|
                         tracker.track_complete(e)
                         aggregator.add(e.agent_name, e.output)
                       end
                       .on(:error) { |e| tracker.track_error(e) }
                       .build

      { team:, tracker:, aggregator: }
    end

    # Build for testing with mock models
    def self.build_for_testing(coordinator_responses:, researcher_responses:)
      coordinator = Smolagents::Testing::MockModel.new(model_id: "mock-coordinator")
      coordinator_responses.each { |r| coordinator.queue_response(r) }

      # Each researcher gets their own mock
      broad_mock = Smolagents::Testing::MockModel.new(model_id: "mock-broad")
      deep_mock = Smolagents::Testing::MockModel.new(model_id: "mock-deep")
      academic_mock = Smolagents::Testing::MockModel.new(model_id: "mock-academic")

      researcher_responses[:broad]&.each { |r| broad_mock.queue_response(r) }
      researcher_responses[:deep]&.each { |r| deep_mock.queue_response(r) }
      researcher_responses[:academic]&.each { |r| academic_mock.queue_response(r) }

      tracker = SwarmTracker.new
      aggregator = ResearchAggregator.new

      # Create researchers with individual mocks
      broad = Smolagents.agent
                        .model { broad_mock }
                        .tool(:web_search, "Search web", query: String) { |query:| "Results for #{query}" }
                        .max_steps(3)
                        .build

      deep = Smolagents.agent
                       .model { deep_mock }
                       .tool(:scrape_page, "Scrape page", url: String) { |url:| "Content from #{url}" }
                       .max_steps(3)
                       .build

      academic = Smolagents.agent
                           .model { academic_mock }
                           .tool(:arxiv_search, "Search papers", topic: String) { |topic:| "Papers on #{topic}" }
                           .max_steps(3)
                           .build

      team = Smolagents.team
                       .model { coordinator }
                       .agent(broad, as: "broad_researcher")
                       .agent(deep, as: "deep_researcher")
                       .agent(academic, as: "academic_researcher")
                       .max_steps(10)
                       .on(:agent_launch) { |e| tracker.track_launch(e) }
                       .on(:agent_complete) do |e|
                         tracker.track_complete(e)
                         aggregator.add(e.agent_name, e.output)
                       end
                       .on(:error) { |e| tracker.track_error(e) }
                       .build

      {
        team:,
        tracker:,
        aggregator:,
        models: {
          coordinator:,
          broad: broad_mock,
          deep: deep_mock,
          academic: academic_mock
        }
      }
    end
  end
end

# =============================================================================
# DEMO
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Research Swarm Experiment"
  puts "=" * 40
  puts
  puts "This experiment demonstrates:"
  puts "1. Multi-agent coordination with TeamBuilder"
  puts "2. Parallel research strategies (broad, deep, academic)"
  puts "3. Result aggregation and synthesis"
  puts "4. Event-driven tracking of swarm activity"
  puts
  puts "Architecture:"
  puts "  Coordinator → [Broad, Deep, Academic] → Synthesizer"
  puts
  puts "To test:"
  puts "  bundle exec rspec spec/experiments/multi_model_agents/05_research_swarm_spec.rb"
end
