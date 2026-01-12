module Smolagents
  module Agents
    # Specialized agent for audio transcription tasks.
    #
    # Uses CodeAgent with speech-to-text and Ruby processing for
    # transcription and post-processing.
    #
    # @example Basic usage
    #   transcriber = Transcriber.new(model: my_model)
    #   result = transcriber.run("Transcribe audio.mp3 and summarize key points")
    #
    # @example With different provider
    #   transcriber = Transcriber.new(model: my_model, provider: "whisper")
    #
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see SpeechToTextTool For direct transcription without agent
    class Transcriber < Code
      include Concerns::Specialized

      instructions <<~TEXT
        You are an audio transcription specialist. Your approach:
        1. Transcribe the audio file to text
        2. Clean up the transcription if needed
        3. Extract key information or summarize as requested
        4. Format the output clearly with timestamps if available
      TEXT

      default_tools do |options|
        provider = options[:provider] || "openai"
        [
          Smolagents::SpeechToTextTool.new(provider: provider),
          Smolagents::RubyInterpreterTool.new,
          Smolagents::FinalAnswerTool.new
        ]
      end
    end
  end
end
