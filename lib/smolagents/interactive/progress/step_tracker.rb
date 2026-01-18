module Smolagents
  module Interactive
    module Progress
      # Tracks and displays step progress during agent execution.
      #
      # Shows current step number with visual progress indicator:
      #   [Step 3/10] Processing tool results...
      #
      # @example Usage
      #   tracker = StepTracker.new(max_steps: 10)
      #   tracker.start_step(1, "Analyzing query")
      #   tracker.complete_step(1, :success)
      #   tracker.start_step(2, "Searching")
      #
      class StepTracker
        extend ColorHelpers

        def initialize(max_steps: 10, output: $stdout)
          @max_steps = max_steps
          @output = output
          @current_step = 0
          @completed_steps = []
        end

        attr_reader :current_step, :max_steps, :completed_steps

        def start_step(step_number, description = nil)
          @current_step = step_number
          return unless tty?

          clear_line
          @output.print step_line(step_number, description)
          @output.flush
        end

        def complete_step(step_number, outcome = :success)
          @completed_steps << { step: step_number, outcome: }
          return unless tty?

          clear_line
          @output.puts completion_line(step_number, outcome)
        end

        def update_description(description)
          return unless tty?

          clear_line
          @output.print step_line(@current_step, description)
          @output.flush
        end

        def progress_percentage
          return 0 if @max_steps.zero?

          (@completed_steps.size.to_f / @max_steps * 100).round
        end

        def reset
          @current_step = 0
          @completed_steps = []
        end

        private

        def step_line(step_number, description)
          prefix = step_prefix(step_number)
          description ? "#{prefix} #{dim(description)}" : prefix
        end

        def step_prefix(step_number)
          "#{dim("[")}#{bold("Step #{step_number}")}#{dim("/#{@max_steps}]")}"
        end

        def completion_line(step_number, outcome)
          icon = outcome_icon(outcome)
          "#{dim("─")} Step #{step_number} #{icon}"
        end

        def outcome_icon(outcome)
          case outcome
          when :success, :final_answer then green("✓")
          when :error then yellow("!")
          else dim("○")
          end
        end

        def clear_line
          @output.print "\r\e[K"
        end

        def tty? = @output.respond_to?(:tty?) && @output.tty?
        def bold(text) = Colors.wrap(text, Colors::BOLD)
        def dim(text) = Colors.wrap(text, Colors::DIM)
        def green(text) = Colors.wrap(text, Colors::BRIGHT_GREEN)
        def yellow(text) = Colors.wrap(text, Colors::YELLOW)
      end
    end
  end
end
