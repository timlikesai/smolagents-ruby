module Smolagents
  module Interactive
    # ANSI color codes for terminal output.
    module Colors
      RESET = "\e[0m".freeze
      BOLD = "\e[1m".freeze
      DIM = "\e[2m".freeze

      GREEN = "\e[32m".freeze
      YELLOW = "\e[33m".freeze
      BLUE = "\e[34m".freeze
      MAGENTA = "\e[35m".freeze
      CYAN = "\e[36m".freeze
      WHITE = "\e[37m".freeze

      BRIGHT_GREEN = "\e[92m".freeze
      BRIGHT_YELLOW = "\e[93m".freeze
      BRIGHT_BLUE = "\e[94m".freeze
      BRIGHT_CYAN = "\e[96m".freeze

      class << self
        def enabled?
          @enabled.nil? ? $stdout.tty? : @enabled
        end

        attr_writer :enabled

        def wrap(text, *codes)
          return text unless enabled?

          "#{codes.join}#{text}#{RESET}"
        end
      end
    end

    # Color helper methods for display classes.
    module ColorHelpers
      def bold(text) = Colors.wrap(text, Colors::BOLD)
      def dim(text) = Colors.wrap(text, Colors::DIM)
      def green(text) = Colors.wrap(text, Colors::BRIGHT_GREEN)
      def yellow(text) = Colors.wrap(text, Colors::YELLOW)
      def cyan(text) = Colors.wrap(text, Colors::CYAN)
      def magenta(text) = Colors.wrap(text, Colors::MAGENTA)
      def section(title) = Colors.wrap(title, Colors::BOLD, Colors::WHITE)
    end
  end
end
