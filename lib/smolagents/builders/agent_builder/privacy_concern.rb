module Smolagents
  module Builders
    # Privacy configuration for AgentBuilder.
    #
    # Provides DSL methods for configuring PII detection and protection
    # in agent processing pipelines.
    module AgentPrivacyConcern
      # Enable privacy protection with tokenization (reversible, default).
      #
      # @example Default protection
      #   agent = Smolagents.agent
      #     .model { my_model }
      #     .with_privacy
      #     .build
      #
      # @example Strict mode (all PII types)
      #   agent = Smolagents.agent
      #     .model { my_model }
      #     .with_privacy(:strict)
      #     .build
      #
      # @example Custom types with masking
      #   agent = Smolagents.agent
      #     .model { my_model }
      #     .with_privacy(types: [:email, :phone], strategy: :mask)
      #     .build
      #
      # @param preset [Symbol, nil] :default, :strict, or nil for custom
      # @param types [Array<Symbol>] PII types to detect
      # @param strategy [Symbol] :tokenize, :mask, or :remove
      # @param preserve_format [Boolean] Keep structure in masked values
      # @return [AgentBuilder] New builder with privacy configured
      def with_privacy(preset = :default, types: nil, strategy: :tokenize, preserve_format: true)
        check_frozen!
        config = privacy_config_for(preset, types, strategy, preserve_format)
        with_config(privacy_config: config)
      end

      # Disable privacy protection.
      # @return [AgentBuilder] New builder with privacy disabled
      def without_privacy
        check_frozen!
        with_config(privacy_config: Types::PrivacyConfig.disabled)
      end

      private

      def privacy_config_for(preset, types, strategy, preserve_format)
        return Types::PrivacyConfig.strict if preset == :strict
        return Types::PrivacyConfig.create(types:, strategy:, preserve_format:) if types

        Types::PrivacyConfig.default
      end

      # Configure privacy protection for the agent.
      def configure_privacy(agent)
        config = configuration[:privacy_config]
        return unless config&.enabled?

        agent.setup_privacy(config) if agent.respond_to?(:setup_privacy)
      end
    end
  end
end
