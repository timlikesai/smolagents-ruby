module Smolagents
  module Types
    # Configuration for checkpoint behavior.
    #
    # Controls checkpoint creation, storage, and management. Supports
    # automatic checkpointing at intervals and persistence to disk.
    #
    # @example Default configuration
    #   config = CheckpointConfig.default
    #   config.enabled?  # => true
    #
    # @example Persistent checkpointing
    #   config = CheckpointConfig.persistent(path: "/tmp/checkpoints", interval: 5)
    #
    # @see Checkpoint For the checkpoint type
    CheckpointConfig = Data.define(:max_checkpoints, :auto_save_path, :interval, :enabled) do
      DEFAULT_MAX_CHECKPOINTS = 10

      # @return [CheckpointConfig] Default config with checkpointing enabled
      def self.default
        new(max_checkpoints: DEFAULT_MAX_CHECKPOINTS, auto_save_path: nil, interval: nil, enabled: true)
      end

      # @return [CheckpointConfig] Config with checkpointing disabled
      def self.disabled
        new(max_checkpoints: 0, auto_save_path: nil, interval: nil, enabled: false)
      end

      # Creates config with persistent storage.
      # @param path [String] Directory for checkpoint files
      # @param interval [Integer, nil] Steps between auto-saves
      # @param max_checkpoints [Integer] Maximum to retain
      # @return [CheckpointConfig]
      def self.persistent(path:, interval: nil, max_checkpoints: DEFAULT_MAX_CHECKPOINTS)
        new(max_checkpoints:, auto_save_path: path, interval:, enabled: true)
      end

      # Creates config for auto-checkpointing at intervals.
      # @param interval [Integer] Steps between checkpoints
      # @param path [String, nil] Optional persistent storage path
      # @param max_checkpoints [Integer] Maximum to retain
      # @return [CheckpointConfig]
      def self.auto(interval:, path: nil, max_checkpoints: DEFAULT_MAX_CHECKPOINTS)
        new(max_checkpoints:, auto_save_path: path, interval:, enabled: true)
      end

      # @return [Boolean] True if checkpointing is enabled
      def enabled? = enabled == true

      # @return [Boolean] True if persistent storage is configured
      def persistent? = !auto_save_path.nil? && !auto_save_path.empty?

      # @return [Boolean] True if auto-checkpointing is configured
      def auto? = !interval.nil? && interval.positive?

      # @param step_number [Integer] Current step number
      # @return [Boolean] True if checkpoint should be created at this step
      def should_checkpoint?(step_number)
        return false unless enabled? && auto?

        (step_number % interval).zero?
      end
    end
  end
end
