module Smolagents
  module Agents
    class Transcriber < Code
      INSTRUCTIONS = <<~TEXT.freeze
        You are an audio transcription specialist. Your approach:
        1. Transcribe the audio file to text
        2. Clean up the transcription if needed
        3. Extract key information or summarize as requested
        4. Format the output clearly with timestamps if available
      TEXT

      def initialize(model:, provider: "openai", **)
        @provider = provider
        super(
          tools: default_tools,
          model: model,
          custom_instructions: INSTRUCTIONS,
          **
        )
      end

      private

      def default_tools
        [
          Smolagents::SpeechToTextTool.new(provider: @provider),
          Smolagents::RubyInterpreterTool.new,
          Smolagents::FinalAnswerTool.new
        ]
      end
    end
  end
end
