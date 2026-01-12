require_relative "final_answer"
require_relative "ruby_interpreter"
require_relative "user_input"
require_relative "duckduckgo_search"
require_relative "bing_search"
require_relative "brave_search"
require_relative "google_search"
require_relative "wikipedia_search"
require_relative "visit_webpage"
require_relative "speech_to_text"

module Smolagents
  module Tools
    REGISTRY = {
      "final_answer" => FinalAnswerTool,
      "ruby_interpreter" => RubyInterpreterTool,
      "user_input" => UserInputTool,
      "duckduckgo_search" => DuckDuckGoSearchTool,
      "bing_search" => BingSearchTool,
      "brave_search" => BraveSearchTool,
      "google_search" => GoogleSearchTool,
      "wikipedia_search" => WikipediaSearchTool,
      "visit_webpage" => VisitWebpageTool,
      "speech_to_text" => SpeechToTextTool
    }.freeze

    def self.get(name) = REGISTRY[name.to_s]&.new
    def self.all = REGISTRY.values.map(&:new)
    def self.names = REGISTRY.keys
  end

  DefaultTools = Tools
end
