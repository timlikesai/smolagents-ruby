module Smolagents
  module Types
    # Configuration for tool recovery behavior (PALADIN pattern).
    #
    # Defines which recovery actions are allowed and configures fallback
    # tool mappings for the SWITCH action.
    #
    # @example Using default configuration
    #   config = ToolRecoveryConfig.default
    #   config.can_retry?     # => true
    #   config.can_reformat?  # => true
    #   config.can_switch?    # => false
    #
    # @example With fallback tools
    #   config = ToolRecoveryConfig.default.with(
    #     allow_switch: true,
    #     fallback_tools: { "search" => "web_search" }
    #   )
    #   config.fallback?("search")  # => true
    #   config.fallback_for("search")   # => "web_search"
    #
    # @see ToolRecovery For the recovery implementation
    ToolRecoveryConfig = Data.define(
      :enabled,
      :max_attempts,
      :allow_retry,
      :allow_reformat,
      :allow_switch,
      :fallback_tools
    ) do
      include TypeSupport::Deconstructable

      # Default configuration with retry and reformat enabled.
      # @return [ToolRecoveryConfig]
      def self.default
        new(
          enabled: true,
          max_attempts: 3,
          allow_retry: true,
          allow_reformat: true,
          allow_switch: false,
          fallback_tools: {}
        )
      end

      # Disabled configuration (no recovery).
      # @return [ToolRecoveryConfig]
      def self.disabled
        new(
          enabled: false,
          max_attempts: 0,
          allow_retry: false,
          allow_reformat: false,
          allow_switch: false,
          fallback_tools: {}
        )
      end

      # Whether recovery is disabled.
      # @return [Boolean]
      def disabled? = !enabled

      # Whether retry action is allowed.
      # @return [Boolean]
      def can_retry? = enabled && allow_retry

      # Whether reformat action is allowed.
      # @return [Boolean]
      def can_reformat? = enabled && allow_reformat

      # Whether switch action is allowed.
      # @return [Boolean]
      def can_switch? = enabled && allow_switch

      # Whether a fallback tool is configured for the given tool.
      # @param tool_name [String] The tool name
      # @return [Boolean]
      def fallback?(tool_name) = fallback_tools.key?(tool_name)

      # Get the fallback tool for the given tool.
      # @param tool_name [String] The tool name
      # @return [String, nil] The fallback tool name or nil
      def fallback_for(tool_name) = fallback_tools[tool_name]
    end
  end
end
