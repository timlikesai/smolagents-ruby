require_relative "../base_concern"
require_relative "specialized/class_methods"
require_relative "specialized/instance_methods"

module Smolagents
  module Concerns
    # DSL concern for defining specialized agents with minimal boilerplate.
    #
    # Small LLMs (1-4B params) perform best with focused, narrow roles.
    # Specialized agents encode domain knowledge and tool preferences
    # directly in the class definition.
    #
    # @example Defining a specialized agent
    #   class MySearchAgent < Agents::Agent
    #     include Concerns::Specialized
    #
    #     instructions <<~TEXT
    #       You are a search specialist. Your approach:
    #       1. Search for relevant information
    #       2. Summarize findings
    #     TEXT
    #
    #     default_tools :duckduckgo_search, :visit_webpage, :final_answer
    #   end
    #
    #   agent = MySearchAgent.new(model: my_model)
    #
    # @example With configurable tool options
    #   class FactChecker < Agents::Agent
    #     include Concerns::Specialized
    #
    #     instructions "You are a fact-checking specialist..."
    #
    #     default_tools do |options|
    #       search = case options[:search_provider]
    #                when :google then GoogleSearchTool.new
    #                else DuckDuckGoSearchTool.new
    #                end
    #       [search, WikipediaSearchTool.new, FinalAnswerTool.new]
    #     end
    #   end
    #
    #   agent = FactChecker.new(model: my_model, search_provider: :google)
    #
    # @see Specialized::ClassMethods For class-level DSL methods
    # @see Specialized::InstanceMethods For instance behavior
    module Specialized
      BaseConcern.define_composite(self, InstanceMethods, class_methods: ClassMethods)
    end
  end
end
