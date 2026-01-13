module Smolagents
  module Types
    # Fluent DSL for building hierarchical outcome trees.
    #
    # OutcomeTree makes it easy for both humans and LLMs to express complex,
    # multi-step plans with dependencies, success criteria, and sub-agent spawning.
    #
    # @example Simple linear plan
    #   tree = Outcome.plan("Research AI safety") do
    #     step "Find recent papers" do
    #       expect results: 10..20, recency: 30.days
    #     end
    #
    #     step "Analyze sentiment" do
    #       expect confidence: 0.8..1.0
    #     end
    #   end
    #
    # @example With sub-agents and dependencies
    #   tree = Outcome.plan("Complete market research") do
    #     step "Gather data", agent: :web_searcher do
    #       expect sources: 10..15, recency: 7.days
    #     end
    #
    #     step "Analyze competitors", depends_on: "Gather data" do
    #       spawn_agent :analyzer, model: "gpt-4"
    #       expect insights: 5..10
    #     end
    #
    #     parallel do
    #       step "Create charts" do
    #         expect format: "png", count: 3..5
    #       end
    #
    #       step "Write summary" do
    #         expect length: 500..1000
    #       end
    #     end
    #   end
    #
    # @example Nested decomposition
    #   tree = Outcome.plan("Build web scraper") do
    #     step "Design architecture" do
    #       step "Choose libraries"
    #       step "Define data models"
    #       step "Plan error handling"
    #     end
    #
    #     step "Implement", depends_on: "Design architecture" do
    #       step "Core scraping logic"
    #       step "Data validation"
    #       step "Storage layer"
    #     end
    #   end
    #
    class OutcomeTree
      attr_reader :root, :steps, :dependencies

      def initialize(description, &block)
        @root = Outcome.desired(description)
        @steps = {} # name => outcome
        @dependencies = {} # step_name => [dependency_names]
        @current_parent = @root
        @step_counter = 0

        instance_eval(&block) if block
      end

      # DSL: Define a step in the plan
      # @param description [String] Human-readable step description
      # @param agent [Symbol] Agent type to use (optional)
      # @param depends_on [String, Array<String>] Dependencies (optional)
      # @example
      #   step "Find sources", agent: :web_searcher, depends_on: "Define query"
      def step(description, agent: nil, depends_on: nil, &block)
        step_name = normalize_name(description)
        @step_counter += 1

        # Create outcome for this step
        outcome = Outcome.desired(
          description,
          metadata: {
            step_number: @step_counter,
            agent_type: agent
          }.compact
        )

        # Track dependencies
        @dependencies[step_name] = Array(depends_on).map { |d| normalize_name(d) } if depends_on

        # Add to parent
        @current_parent = @current_parent.add_child(outcome)
        @steps[step_name] = @current_parent.children.last

        # Process nested block
        if block
          previous_parent = @current_parent
          @current_parent = @steps[step_name]
          instance_eval(&block)
          @current_parent = previous_parent
        end

        @steps[step_name]
      end

      # DSL: Define success criteria for current step
      # @example
      #   step "Find papers" do
      #     expect count: 10..20, quality: ->(v) { v > 0.8 }
      #   end
      def expect(**criteria)
        current_step = @current_parent.children.last
        return unless current_step

        updated = current_step.with(criteria: current_step.criteria.merge(criteria))
        update_last_child(updated)
      end

      # DSL: Specify agent to spawn for this step
      # @example
      #   step "Analyze data" do
      #     spawn_agent :analyzer, model: "claude-3.5-sonnet"
      #   end
      def spawn_agent(agent_type, **config)
        current_step = @current_parent.children.last
        return unless current_step

        updated_metadata = current_step.metadata.merge(
          agent_type: agent_type,
          agent_config: config
        )
        updated = current_step.with(metadata: updated_metadata)
        update_last_child(updated)
      end

      # DSL: Use specific agent type for this step (alias for spawn_agent)
      # @example
      #   step "Search web" do
      #     use_agent :web_searcher
      #   end
      def use_agent(agent_type, **config)
        spawn_agent(agent_type, **config)
      end

      # DSL: Define parallel steps (no dependencies between them)
      # @example
      #   parallel do
      #     step "Task A"
      #     step "Task B"
      #     step "Task C"
      #   end
      def parallel(&)
        parallel_marker = @step_counter
        instance_eval(&)

        # Mark all steps defined in this block as parallel
        steps_in_parallel = @steps.select { |_, outcome| outcome.metadata[:step_number] > parallel_marker }
        steps_in_parallel.each do |name, outcome|
          updated = outcome.with(metadata: outcome.metadata.merge(parallel: true))
          @steps[name] = updated
        end
      end

      # Execute the outcome tree, tracking actual vs desired
      # @example
      #   results = tree.execute do |desired_step, context|
      #     # Agent executes the step
      #     agent.run(desired_step.description)
      #   end
      def execute(&block)
        raise ArgumentError, "Block required for execution" unless block

        # Build execution order respecting dependencies
        execution_order = topological_sort

        results = {}

        execution_order.each do |step_name|
          desired = @steps[step_name]

          # Skip if parent failed
          next if desired.parent && results[desired.parent.description]&.failed?

          # Execute step
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          begin
            value = yield(desired, results)
            duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

            actual = Outcome.actual(
              desired.description,
              state: :success,
              value: value,
              duration: duration,
              metadata: desired.metadata
            )
          rescue StandardError => e
            duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

            actual = Outcome.actual(
              desired.description,
              state: :error,
              value: nil,
              error: e,
              duration: duration,
              metadata: desired.metadata
            )
          end

          results[step_name] = actual
        end

        results
      end

      # Get execution order respecting dependencies (topological sort)
      def topological_sort
        sorted = []
        visited = {}
        temp_mark = {}

        visit = lambda do |step_name|
          return if visited[step_name]
          raise "Circular dependency detected: #{step_name}" if temp_mark[step_name]

          temp_mark[step_name] = true

          # Visit dependencies first
          (@dependencies[step_name] || []).each { |dep| visit.call(dep) }

          temp_mark[step_name] = false
          visited[step_name] = true
          sorted << step_name
        end

        @steps.each_key { |step_name| visit.call(step_name) }
        sorted
      end

      # Visualize the outcome tree
      def trace
        @root.trace.join("\n")
      end

      # Convert to hash for serialization
      def to_h
        {
          description: @root.description,
          steps: @steps.transform_values(&:to_event_payload),
          dependencies: @dependencies,
          execution_order: topological_sort
        }
      end

      private

      def normalize_name(description)
        description.downcase.gsub(/\s+/, "_")
      end

      def update_last_child(updated)
        parent = @current_parent
        last_idx = parent.children.length - 1
        new_children = parent.children.dup
        new_children[last_idx] = updated
        @current_parent = parent.with(children: new_children)

        # Update in steps hash
        step_name = normalize_name(updated.description)
        @steps[step_name] = updated
      end
    end

    # Extend Outcome class with tree builder
    class << Outcome
      # DSL: Build an outcome tree (planning)
      # @example
      #   tree = Outcome.plan("Research project") do
      #     step "Find sources"
      #     step "Analyze", depends_on: "Find sources"
      #   end
      def plan(description, &)
        OutcomeTree.new(description, &)
      end

      # DSL: Build outcome from agent execution
      # @example
      #   Outcome.from_agent_result(result, desired: desired_outcome)
      def from_agent_result(result, desired: nil)
        actual(
          desired&.description || "Agent execution",
          state: map_result_state(result.state),
          value: result.output,
          duration: result.timing&.duration || 0.0,
          metadata: {
            steps_taken: result.steps&.size || 0,
            tokens: result.token_usage&.total_tokens || 0
          }
        )
      end

      private

      def map_result_state(result_state)
        case result_state
        when :success then :success
        when :max_steps_reached then :partial
        when :error then :error
        else :pending
        end
      end
    end
  end
end
