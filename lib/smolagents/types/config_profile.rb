module Smolagents
  module Types
    # Immutable configuration profile for environment-specific settings.
    #
    # Profiles define named sets of configuration overrides that inherit from
    # defaults. Use for switching between local GPU, cloud API, and development
    # settings without changing code.
    #
    # @example Built-in local GPU profile
    #   profile = ConfigProfile.local_gpu
    #   profile.name         # => :local_gpu
    #   profile.overrides    # => { http: { timeout_seconds: 60 }, ... }
    #
    # @example Custom profile
    #   profile = ConfigProfile.new(
    #     name: :staging,
    #     description: "Staging environment",
    #     overrides: { max_steps: 15, log_level: :info }
    #   )
    #
    # @see Config::Profiles For profile registry and application
    ConfigProfile = Data.define(:name, :description, :overrides) do
      include TypeSupport::Deconstructable

      # Default (empty) profile — no overrides.
      # @return [ConfigProfile]
      def self.default
        new(name: :default, description: "Default settings — no overrides", overrides: {})
      end

      # Local GPU profile — tuned for local model constraints.
      #
      # Higher timeouts, fewer steps, more tolerant health thresholds.
      # @return [ConfigProfile]
      def self.local_gpu
        new(
          name: :local_gpu,
          description: "Tuned for local GPU models — higher timeouts, conservative steps",
          overrides: {
            http: { timeout_seconds: 60 },
            max_steps: 10,
            health: { latency_healthy_ms: 3000, latency_degraded_ms: 10_000 }
          }
        )
      end

      # Development profile — verbose logging for debugging.
      # @return [ConfigProfile]
      def self.development
        new(
          name: :development,
          description: "Verbose logging for development and debugging",
          overrides: { log_level: :debug }
        )
      end

      # Cloud API profile — optimized for cloud providers.
      # @return [ConfigProfile]
      def self.cloud_api
        new(
          name: :cloud_api,
          description: "Optimized for cloud API providers",
          overrides: {
            http: { timeout_seconds: 30 },
            max_steps: 20
          }
        )
      end

      # Whether this profile has any overrides.
      # @return [Boolean]
      def empty? = overrides.empty?

      # List of top-level configuration keys this profile overrides.
      # @return [Array<Symbol>]
      def override_keys = overrides.keys

      # Merge another profile's overrides on top of this one.
      # @param other [ConfigProfile] Profile to merge
      # @return [ConfigProfile] New profile with merged overrides
      def merge(other)
        with(
          name: :"#{name}_#{other.name}",
          description: "Merged: #{description} + #{other.description}",
          overrides: deep_merge(overrides, other.overrides)
        )
      end

      # Serializable hash representation.
      # @return [Hash]
      def to_h = { name:, description:, overrides: }

      private

      def deep_merge(base, overlay)
        base.merge(overlay) do |_key, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge(old_val, new_val)
          else
            new_val
          end
        end
      end
    end
  end
end
