module Smolagents
  module Types
    # Configuration for agent planning behavior.
    #
    # PlanningConfig controls the Pre-Act planning phase that occurs before
    # action execution. Planning helps agents decompose complex tasks and
    # maintain focus on the goal.
    #
    # == Options
    #
    # - +:interval+ - Steps between planning phases (nil = disabled)
    # - +:templates+ - Custom planning prompt templates
    #
    # @example Disabled planning (default)
    #   config = PlanningConfig.default
    #   config.enabled?  # => false
    #
    # @example Enable planning every 3 steps
    #   config = PlanningConfig.create(interval: 3)
    #   config.enabled?  # => true
    #
    # @see Concerns::Agents::Planning Planning implementation
    PlanningConfig = Data.define(:interval, :templates) do
      # Creates a default config with planning disabled.
      #
      # @return [PlanningConfig] Config with nil interval
      def self.default
        new(interval: nil, templates: nil)
      end

      # Creates a planning config with the given options.
      #
      # @param interval [Integer, nil] Steps between planning phases
      # @param templates [Hash, nil] Custom prompt templates
      # @return [PlanningConfig]
      def self.create(interval: nil, templates: nil)
        new(interval:, templates:)
      end

      # Checks if planning is enabled.
      #
      # @return [Boolean] True if interval is set
      def enabled? = !interval.nil?

      # Checks if planning is disabled.
      #
      # @return [Boolean] True if interval is nil
      def disabled? = interval.nil?

      # Checks if custom templates are provided.
      #
      # @return [Boolean] True if templates is set
      def custom_templates? = !templates.nil?
    end
  end
end
