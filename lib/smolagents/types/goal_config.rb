module Smolagents
  module Types
    # Configuration for goal tracking behavior.
    #
    # @example Default (enabled)
    #   config = GoalConfig.new
    #   config.enabled  # => true
    #
    # @example Disabled
    #   config = GoalConfig.disabled
    #   config.enabled  # => false
    GoalConfig = Data.define(:enabled, :visible) do
      # Creates default enabled configuration.
      def initialize(enabled: true, visible: false)
        super
      end

      # Creates a disabled configuration.
      # @return [GoalConfig]
      def self.disabled = new(enabled: false, visible: false)

      # Creates configuration with goals visible in output.
      # @return [GoalConfig]
      def self.visible = new(enabled: true, visible: true)
    end
  end
end
