module Smolagents
  module Types
    # Configuration for agent observability and monitoring.
    #
    # ObservabilityConfig controls how observations are routed and
    # summarized during agent execution. This affects how the agent
    # processes tool outputs and maintains context.
    #
    # == Observe Modes
    #
    # - +:with_summary+ - Include summarized observations (default)
    # - +:structure_only+ - Show data structure without LLM summarization
    # - +:raw+ - Include raw observations without summarization
    # - +:minimal+ - Minimal observation detail
    #
    # @example Default observability config
    #   config = ObservabilityConfig.default
    #   config.observe_mode       # => :with_summary
    #   config.summarizer_model   # => nil
    #
    # @example With custom summarizer
    #   config = ObservabilityConfig.create(
    #     observe_mode: :with_summary,
    #     summarizer_model: small_model
    #   )
    #
    # @see Concerns::Agents::ObservationRouter Observation routing
    ObservabilityConfig = Data.define(:observe_mode, :summarizer_model) do
      # Valid observe modes.
      VALID_MODES = %i[with_summary structure_only raw minimal].freeze

      # Creates a default config with summary mode.
      #
      # @return [ObservabilityConfig]
      def self.default
        new(observe_mode: :with_summary, summarizer_model: nil)
      end

      # Creates an observability config with the given options.
      #
      # @param observe_mode [Symbol] Observation mode (:with_summary, :raw, :minimal)
      # @param summarizer_model [Model, nil] Model for summarization
      # @return [ObservabilityConfig]
      # @raise [ArgumentError] If observe_mode is invalid
      def self.create(observe_mode: :with_summary, summarizer_model: nil)
        validate_mode!(observe_mode)
        new(observe_mode:, summarizer_model:)
      end

      # Validates the observe mode.
      # @param mode [Symbol] Mode to validate
      # @raise [ArgumentError] If mode is invalid
      # @api private
      def self.validate_mode!(mode)
        return if VALID_MODES.include?(mode)

        raise ArgumentError, "Invalid observe_mode: #{mode}. Valid: #{VALID_MODES.join(", ")}"
      end

      # Checks if using summary mode.
      #
      # @return [Boolean]
      def with_summary? = observe_mode == :with_summary

      # Checks if using structure-only mode.
      #
      # @return [Boolean]
      def structure_only? = observe_mode == :structure_only

      # Checks if using raw mode.
      #
      # @return [Boolean]
      def raw? = observe_mode == :raw

      # Checks if using minimal mode.
      #
      # @return [Boolean]
      def minimal? = observe_mode == :minimal

      # Checks if a summarizer model is configured.
      #
      # @return [Boolean]
      def summarizer? = !summarizer_model.nil?
    end
  end
end
