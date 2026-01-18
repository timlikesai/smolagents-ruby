module Smolagents
  module Interactive
    module Progress
      # Animated terminal spinner using ANSI escape codes.
      #
      # Provides visual feedback during long-running operations without
      # blocking the main thread. Uses a background thread to animate.
      #
      # @example Basic usage
      #   spinner = Spinner.new
      #   spinner.start("Loading...")
      #   # ... do work ...
      #   spinner.stop
      #
      # @example With completion message
      #   spinner = Spinner.new
      #   spinner.start("Processing")
      #   # ... do work ...
      #   spinner.succeed("Done!")  # Shows green checkmark
      #
      class Spinner
        FRAMES = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze
        INTERVAL = 0.08

        extend ColorHelpers

        def initialize(output: $stdout)
          @output = output
          @thread = nil
          @running = false
          @message = ""
          @frame_index = 0
        end

        def start(message = "")
          return if @running || !tty?

          @message = message
          @running = true
          @thread = Thread.new { animate }
        end

        def stop
          return unless @running

          @running = false
          @thread&.join(0.2)
          @thread = nil
          clear_line
        end

        def succeed(message = nil)
          stop
          print_result(green("✓"), message || @message)
        end

        def fail(message = nil)
          stop
          print_result(yellow("!"), message || @message)
        end

        def update(message)
          @message = message
        end

        def running? = @running

        private

        def animate
          while @running
            render_frame
            # rubocop:disable Smolagents/NoSleep -- visual animation timing, not event coordination
            sleep INTERVAL
            # rubocop:enable Smolagents/NoSleep
          end
        end

        def render_frame
          clear_line
          frame = Colors.wrap(FRAMES[@frame_index], Colors::CYAN)
          @output.print "#{frame} #{@message}"
          @output.flush
          @frame_index = (@frame_index + 1) % FRAMES.size
        end

        def clear_line
          @output.print "\r\e[K"
          @output.flush
        end

        def print_result(icon, message)
          @output.puts "#{icon} #{message}" if message && !message.empty?
        end

        def tty? = @output.respond_to?(:tty?) && @output.tty?
        def green(text) = Colors.wrap(text, Colors::BRIGHT_GREEN)
        def yellow(text) = Colors.wrap(text, Colors::YELLOW)
      end
    end
  end
end
