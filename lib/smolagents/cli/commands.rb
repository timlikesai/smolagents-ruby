require_relative "commands/display"
require_relative "commands/execute"
require_relative "commands/info"

module Smolagents
  module CLI
    # Command implementations for the CLI interface.
    #
    # This module composes focused command modules for running tasks, listing tools,
    # and displaying model information. Intended to be included in a Thor command class.
    #
    # @example Running a task
    #   class MyCLI < Thor
    #     include Smolagents::CLI::Commands
    #     include Smolagents::CLI::ModelBuilder
    #   end
    #
    #   MyCLI.start(["execute", "What is the capital of France?"])
    #
    # @see Main
    # @see ModelBuilder
    module Commands
      def self.included(base)
        base.include(Display)
        base.include(Execute)
        base.include(Info)
      end
    end
  end
end
