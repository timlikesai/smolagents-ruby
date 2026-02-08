module Smolagents
  module Types
    # Configuration for plan template caching.
    #
    # Controls cache behavior including size limits, TTL, and similarity
    # threshold for task matching. Provides factory methods for common
    # configurations.
    #
    # @example Default configuration
    #   config = PlanCacheConfig.default
    #   config.max_size        #=> 100
    #   config.ttl_seconds     #=> 3600
    #
    # @example Disabled caching
    #   config = PlanCacheConfig.disabled
    #   config.disabled?  #=> true
    #
    # @see CachedPlan For cached plan structure
    # @see Concerns::Caching::PlanTemplate For cache operations
    PlanCacheConfig = Data.define(
      :enabled,
      :max_size,
      :ttl_seconds,
      :similarity_threshold
    ) do
      class << self
        # Creates default caching configuration.
        #
        # @return [PlanCacheConfig] Default config with caching enabled
        def default
          new(
            enabled: true,
            max_size: 100,
            ttl_seconds: 3600,
            similarity_threshold: 0.85
          )
        end

        # Creates disabled caching configuration.
        #
        # @return [PlanCacheConfig] Config with caching disabled
        def disabled
          new(
            enabled: false,
            max_size: 0,
            ttl_seconds: 0,
            similarity_threshold: 1.0
          )
        end
      end

      # Checks if caching is disabled.
      #
      # @return [Boolean] True if caching is disabled
      def disabled? = !enabled
    end
  end
end
