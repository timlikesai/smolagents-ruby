require_relative "smolagents/version"
require_relative "smolagents/utilities/secret_redactor"
require_relative "smolagents/errors"
require_relative "smolagents/utilities"
require_relative "smolagents/telemetry"
require_relative "smolagents/concerns"
require_relative "smolagents/types"
require_relative "smolagents/config"
require_relative "smolagents/executors"
require_relative "smolagents/models"
require_relative "smolagents/tools"
require_relative "smolagents/pipeline"
require_relative "smolagents/persistence"
require_relative "smolagents/orchestrators"
require_relative "smolagents/agents"

module Smolagents
  class << self
    # Create a new pipeline for composing tools
    #
    # @example
    #   Smolagents.pipeline
    #     .call(:search, query: :input)
    #     .then(:visit) { |r| { url: r.first[:url] } }
    #     .run(query: "Ruby")
    #
    # @return [Pipeline] New empty pipeline
    def pipeline
      Pipeline.new
    end

    # Execute a tool and return a chainable pipeline
    #
    # @example
    #   Smolagents.run(:search, query: "Ruby")
    #     .then(:visit) { |r| { url: r.first[:url] } }
    #     .result
    #
    # @param tool_name [Symbol, String] Tool to execute
    # @param args [Hash] Arguments for the tool
    # @return [Pipeline] Pipeline with the tool call added
    def run(tool_name, **args)
      Pipeline.new.call(tool_name, **args)
    end
  end
end
