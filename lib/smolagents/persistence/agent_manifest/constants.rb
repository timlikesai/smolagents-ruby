module Smolagents
  module Persistence
    module AgentManifestConstants
      # Current manifest format version
      VERSION = "1.0".freeze

      # Agent classes allowed to be loaded from manifests.
      # Prevents arbitrary code execution via malicious manifests.
      ALLOWED_CLASSES = Set.new(%w[
                                  Smolagents::Agents::Agent
                                  Smolagents::Agents::Assistant
                                  Smolagents::Agents::Calculator
                                  Smolagents::Agents::DataAnalyst
                                  Smolagents::Agents::FactChecker
                                  Smolagents::Agents::Researcher
                                  Smolagents::Agents::Transcriber
                                  Smolagents::Agents::WebScraper
                                ]).freeze

      # Required fields for manifest validation
      REQUIRED_FIELDS = %i[version agent_class model].freeze

      # Fields that support direct extraction from agent
      EXTRACTABLE_FIELDS = {
        max_steps: :max_steps,
        planning_interval: :@planning_interval,
        custom_instructions: :@custom_instructions
      }.freeze
    end
  end
end
