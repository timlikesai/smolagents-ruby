require_relative "tools/final_answer"
require_relative "tools/ruby_interpreter"
require_relative "tools/user_input"
require_relative "tools/duckduckgo_search"
require_relative "tools/bing_search"
require_relative "tools/brave_search"
require_relative "tools/google_search"
require_relative "tools/wikipedia_search"
require_relative "tools/visit_webpage"
require_relative "tools/speech_to_text"

module Smolagents
  module Tools
    MAPPING = {
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

    def self.get(name) = MAPPING[name.to_s]&.new
    def self.all = MAPPING.values.map(&:new)
    def self.available = MAPPING
    def self.names = MAPPING.keys
  end

  DefaultTools = Tools
end
