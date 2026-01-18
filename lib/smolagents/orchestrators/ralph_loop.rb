module Smolagents
  module Orchestrators
    # Self-referential iteration loop where an agent sees its own previous work.
    #
    # Ralph Loop runs an agent repeatedly, injecting context about previous
    # iterations so the agent can build on its own work rather than starting over.
    #
    # Named after the "Ralph" pattern - the technique of having AI agents
    # review their own work and iterate until a goal is achieved.
    #
    # @see https://ghuntley.com/ralph/ Original Ralph pattern description
    # @see https://claude.ai/code Claude Code's implementation of this pattern
    class RalphLoop
      # @return [Integer] Current iteration number (1-indexed)
      attr_reader :iteration

      # @return [Array<IterationResult>] Results from all completed iterations
      attr_reader :history

      # @param agent [Agent] The agent to run
      # @param prompt [String] The base task prompt
      # @param max_iterations [Integer] Maximum iterations (0 = unlimited)
      # @param completion_promise [String, nil] Condition for completion
      # @param work_dir [String] Directory to check for git state
      def initialize(agent:, prompt:, max_iterations: 10, completion_promise: nil, work_dir: Dir.pwd)
        @agent = agent
        @prompt = prompt
        @max_iterations = max_iterations
        @completion_promise = completion_promise
        @work_dir = work_dir
        @iteration = 0
        @history = []
      end

      # Run the iteration loop until completion or max iterations.
      # @return [LoopResult] Final result with all iteration history
      def run
        start_time = Time.now
        execute_iterations
        build_loop_result(start_time)
      end

      private

      def execute_iterations
        loop do
          @iteration += 1
          break if exceeded_max_iterations?

          result = run_iteration
          @history << result
          break if should_stop?(result)
        end
      end

      def build_loop_result(start_time)
        LoopResult.new(
          iterations: @history.dup,
          duration: Time.now - start_time,
          completed: completion_achieved?,
          final_output: @history.last&.output
        )
      end

      def exceeded_max_iterations? = @max_iterations.positive? && @iteration > @max_iterations

      def run_iteration
        start_time = Time.now
        run_result = @agent.run(build_iteration_prompt)
        build_success_result(run_result, start_time)
      rescue StandardError => e
        build_error_result(e, start_time)
      end

      def build_success_result(run_result, start_time)
        IterationResult.new(
          iteration: @iteration, output: run_result.output, steps: run_result.steps&.size || 0,
          duration: Time.now - start_time, work_context: capture_work_context
        )
      end

      def build_error_result(error, start_time)
        IterationResult.new(
          iteration: @iteration, output: nil, steps: 0,
          duration: Time.now - start_time, error: error.message, work_context: nil
        )
      end

      def build_iteration_prompt
        [
          @prompt, "", "## Iteration Context",
          iteration_info, "", work_context_section, "",
          "Build on what exists. Do not start over."
        ].compact.join("\n")
      end

      def iteration_info
        max = @max_iterations.positive? ? @max_iterations : "∞"
        info = "Iteration: #{@iteration} of #{max}"
        @completion_promise ? "#{info}\nComplete when: #{@completion_promise}" : info
      end

      def work_context_section
        context = capture_work_context
        context ? format_work_context(context) : "## Previous Work\nNo previous work detected."
      end

      def format_work_context(context)
        lines = ["## Previous Work"]
        lines << "Files modified: #{context[:files_changed].join(", ")}" if context[:files_changed]&.any?
        lines.push("", "Recent commits:", context[:git_log]) if context[:git_log]
        lines.push("", "Current changes:", "```diff", context[:git_diff], "```") if context[:git_diff]
        lines.join("\n")
      end

      def capture_work_context
        return nil unless git_repo?

        { git_log: safe_git("log --oneline -5"), git_diff: safe_git("diff --stat"),
          files_changed: safe_git("diff --name-only")&.split("\n")&.reject(&:empty?) }.compact
      rescue StandardError
        nil
      end

      def git_repo? = Dir.exist?(File.join(@work_dir, ".git"))

      def safe_git(command)
        result = `cd #{@work_dir} && git #{command} 2>/dev/null`.strip
        result.empty? ? nil : result
      end

      def should_stop?(result) = result.error || completion_achieved?

      def completion_achieved?
        return false unless @completion_promise && @history.any?

        output = @history.last&.output.to_s.downcase
        output.include?("complete") || output.include?("done") || output.include?(@completion_promise.downcase)
      end
    end

    # Result of a single iteration.
    IterationResult = Data.define(:iteration, :output, :steps, :duration, :error, :work_context) do
      def initialize(iteration:, output:, steps:, duration:, error: nil, work_context: nil) = super

      def success? = error.nil?
      def failure? = !success?
    end

    # Final result of the entire loop.
    LoopResult = Data.define(:iterations, :duration, :completed, :final_output) do
      def iteration_count = iterations.size
      def success_count = iterations.count(&:success?)
      def failure_count = iterations.count(&:failure?)
      def total_steps = iterations.sum(&:steps)
    end
  end
end
