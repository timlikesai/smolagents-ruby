module Smolagents
  # Type and constant re-exports for convenient top-level access.
  #
  # Groups related exports and uses metaprogramming to reduce repetition.
  # Extended into the Smolagents module to provide direct access.
  #
  # @api private
  module Exports
    # Export groups organized by domain.
    # @api private
    GROUPS = {
      data_types: %i[TokenUsage Timing RunContext ToolCall ToolOutput RunResult],
      steps: %i[ActionStep TaskStep PlanningStep SystemPromptStep FinalAnswerStep NullStep],
      multimodal: %i[AgentType AgentText AgentImage AgentAudio],
      multimodal_constants: %i[ALLOWED_IMAGE_FORMATS ALLOWED_AUDIO_FORMATS AGENT_TYPE_MAPPING],
      enums: %i[MessageRole Outcome PlanState Callbacks],
      outcomes: %i[ExecutionOutcome ExecutorExecutionOutcome OutcomePredicates],
      runtime: %i[ActionStepBuilder AgentMemory ToolStatsAggregator],
      utilities: %i[PatternMatching Prompts Comparison Confidence]
    }.freeze

    def self.extended(base)
      export_from_types(base)
      export_from_runtime(base)
      export_from_infrastructure(base)
    end

    # Exports from Types module - Data.define immutable types.
    # @api private
    def self.export_from_types(base)
      # Bulk exports using defined groups
      %i[data_types steps multimodal multimodal_constants enums outcomes].each do |group|
        GROUPS[group].each { |name| base.const_set(name, Types.const_get(name)) }
      end

      # Single exports
      { ChatMessage: Types, IMAGE_MIME_TYPES: Types, PlanContext: Types,
        InputSchema: Types, ToolStats: Types }.each do |name, source|
        base.const_set(name, source.const_get(name))
      end
    end

    # Exports from Runtime module - mutable builders and aggregators.
    # @api private
    def self.export_from_runtime(base)
      GROUPS[:runtime].each { |name| base.const_set(name, Runtime.const_get(name)) }
    end

    # Exports from infrastructure modules - logging, security, observability.
    # @api private
    def self.export_from_infrastructure(base)
      # Telemetry
      { AgentLogger: Telemetry, Instrumentation: Telemetry }.each do |name, source|
        base.const_set(name, source.const_get(name))
      end

      # Security
      { PromptSanitizer: Security, SecretRedactor: Security }.each do |name, source|
        base.const_set(name, source.const_get(name))
      end

      # Utilities
      GROUPS[:utilities].each { |name| base.const_set(name, Utilities.const_get(name)) }

      # HTTP
      base.const_set(:UserAgent, Http::UserAgent)
    end
  end
end
