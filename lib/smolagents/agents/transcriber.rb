module Smolagents
  module Agents
    # Specialized agent for audio transcription tasks.
    #
    # Uses CodeAgent with speech-to-text and Ruby processing for
    # transcription and intelligent post-processing. Can transcribe, summarize,
    # extract key points, and reformat audio content.
    #
    # The Transcriber agent is optimized for:
    # - Converting audio files to text with high accuracy
    # - Cleaning up transcription artifacts (filler words, stutters)
    # - Extracting and summarizing key points from transcriptions
    # - Formatting transcriptions with timestamps (if available)
    # - Identifying speakers and segmenting conversations
    # - Converting spoken language to written prose
    #
    # Built-in tools:
    # - SpeechToTextTool: Convert audio to text using configurable provider
    #   - OpenAI Whisper (default): Excellent multilingual support, free
    #   - Google Speech-to-Text: High accuracy, requires API key
    # - RubyInterpreterTool: Post-process transcriptions with Ruby
    #   - Remove artifacts, format timestamps
    #   - Extract key phrases, summarize
    #   - Parse speaker changes and segments
    # - FinalAnswerTool: Submit formatted transcription results
    #
    # @example Basic transcription
    #   transcriber = Transcriber.new(model: OpenAIModel.new(model_id: "gpt-4"))
    #   result = transcriber.run("Transcribe audio.mp3 and provide a summary")
    #   puts result.output
    #
    # @example With cleanup and formatting
    #   result = transcriber.run(
    #     "Transcribe the recording from meeting_2025-01-13.wav. " \
    #     "Clean up filler words, standardize formatting, " \
    #     "and provide a brief summary of action items."
    #   )
    #
    # @example Using Google Cloud Speech-to-Text
    #   transcriber = Transcriber.new(
    #     model: my_model,
    #     provider: "google"  # Requires GOOGLE_APPLICATION_CREDENTIALS
    #   )
    #   result = transcriber.run("Transcribe podcast_episode.mp3")
    #
    # @example Conversation analysis
    #   result = transcriber.run(
    #     "Transcribe interview.wav. " \
    #     "Identify speakers, provide timestamps, " \
    #     "and extract key quotes and insights."
    #   )
    #
    # @option kwargs [String] :provider Speech-to-text provider
    #   - "openai" (default): OpenAI Whisper API
    #   - "google": Google Cloud Speech-to-Text
    #   - Other providers may be supported depending on configuration
    # @option kwargs [Integer] :max_steps Steps before giving up (default: 10)
    # @option kwargs [String] :custom_instructions Additional guidance for transcription approach
    #
    # @raise [ArgumentError] If provider is not configured correctly
    # @raise [ArgumentError] If model cannot generate valid Ruby code for post-processing
    #
    # @see Code Base agent type (Ruby code execution)
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see SpeechToTextTool Direct transcription without agent overhead
    # @see RubyInterpreterTool Ruby code execution for text processing
    # @see WebScraper For extracting structured data from text
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
          Smolagents::SpeechToTextTool.new(provider:),
          Smolagents::RubyInterpreterTool.new,
          Smolagents::FinalAnswerTool.new
        ]
      end
    end
  end
end
