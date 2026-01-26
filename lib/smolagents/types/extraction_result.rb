module Smolagents
  module Types
    # Result of code extraction from model response.
    #
    # ExtractionResult captures both successful extractions and failures
    # with rich context about why extraction failed.
    #
    # == Result States
    #
    # - **Success**: {#code} contains extracted Ruby, {#success?} returns true
    # - **Failure**: {#code} is nil, {#reason} explains why
    #
    # == Failure Reasons
    #
    # - +:empty+ - Response was empty or whitespace-only
    # - +:no_code+ - No code block found in response
    # - +:prose_only+ - Response contained only prose, no code
    # - +:truncated+ - Code block was truncated (incomplete)
    #
    # @example Successful extraction
    #   result = ExtractionResult.success("final_answer(answer: 42)")
    #   result.success? #=> true
    #   result.code     #=> "final_answer(answer: 42)"
    #
    # @example Failed extraction
    #   result = ExtractionResult.empty
    #   result.failure? #=> true
    #   result.reason   #=> :empty
    #   result.message  #=> "Response was empty"
    #
    # @example Pattern matching
    #   case result
    #   in ExtractionResult[code:, reason: nil]
    #     execute(code)
    #   in ExtractionResult[reason: :empty]
    #     log_empty_response
    #   in ExtractionResult[reason:]
    #     handle_failure(reason)
    #   end
    #
    # @see PatternMatching.extract_code For extraction logic
    ExtractionResult = Data.define(:code, :reason, :original) do
      # Failure reason descriptions for error messages
      MESSAGES = {
        empty: "Response was empty",
        no_code: "No code block found in response",
        prose_only: "Response contained prose but no executable code",
        truncated: "Code block was truncated or incomplete"
      }.freeze

      # @param code [String, nil] Extracted Ruby code
      # @param reason [Symbol, nil] Failure reason if extraction failed
      # @param original [String, nil] Original text (for debugging failures)
      def initialize(code:, reason: nil, original: nil) = super

      # Creates a successful extraction result.
      # @param code [String] The extracted Ruby code
      # @return [ExtractionResult]
      def self.success(code) = new(code:, reason: nil, original: nil)

      # Creates a failed result for empty/whitespace response.
      # @param original [String, nil] The original response text
      # @return [ExtractionResult]
      def self.empty(original: nil) = new(code: nil, reason: :empty, original:)

      # Creates a failed result when no code block found.
      # @param original [String, nil] The original response text
      # @return [ExtractionResult]
      def self.no_code(original: nil) = new(code: nil, reason: :no_code, original:)

      # Creates a failed result when response is prose only.
      # @param original [String, nil] The original response text
      # @return [ExtractionResult]
      def self.prose_only(original: nil) = new(code: nil, reason: :prose_only, original:)

      # Creates a failed result for truncated code.
      # @param original [String, nil] The original response text
      # @return [ExtractionResult]
      def self.truncated(original: nil) = new(code: nil, reason: :truncated, original:)

      # Checks if extraction succeeded.
      # @return [Boolean]
      def success? = code && reason.nil?

      # Checks if extraction failed.
      # @return [Boolean]
      def failure? = !success?

      # Human-readable error message for the failure reason.
      # @return [String, nil] Message or nil if successful
      def message = MESSAGES[reason]
    end
  end
end
