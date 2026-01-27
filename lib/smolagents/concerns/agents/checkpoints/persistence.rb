require "json"
require "fileutils"

module Smolagents
  module Concerns
    module Checkpoints
      # Persist checkpoints to disk for recovery across sessions.
      #
      # Saves checkpoints as JSON files in the configured directory.
      # Filenames use checkpoint ID for easy lookup.
      #
      # @example Saving
      #   save_checkpoint(checkpoint, "/tmp/checkpoints")
      #
      # @example Loading
      #   checkpoint = load_checkpoint("/tmp/checkpoints/cp_abc123.json")
      module Persistence
        include Serialization

        # Save a checkpoint to disk.
        # @param checkpoint [Types::Checkpoint] The checkpoint to save
        # @param path [String] Directory path for checkpoint files
        # @return [String] Full path to saved file
        def save_checkpoint(checkpoint, path)
          FileUtils.mkdir_p(path)
          file_path = checkpoint_file_path(checkpoint.id, path)
          File.write(file_path, JSON.pretty_generate(serialize_checkpoint(checkpoint)))
          file_path
        end

        # Load a checkpoint from disk.
        # @param file_path [String] Full path to checkpoint file
        # @return [Types::Checkpoint] Loaded checkpoint
        # @raise [Errno::ENOENT] If file doesn't exist
        def load_checkpoint(file_path)
          data = JSON.parse(File.read(file_path), symbolize_names: true)
          deserialize_checkpoint(data)
        end

        # Load all checkpoints from a directory.
        # @param path [String] Directory containing checkpoint files
        # @return [Array<Types::Checkpoint>] All checkpoints, sorted by step
        def load_all_checkpoints(path)
          return [] unless File.directory?(path)

          Dir.glob(File.join(path, "cp_*.json")).filter_map do |file|
            load_checkpoint(file)
          rescue JSON::ParserError, KeyError
            nil
          end.sort_by(&:step_number)
        end

        # Remove a checkpoint file from disk.
        # @param checkpoint_id [String] ID of checkpoint to remove
        # @param path [String] Directory containing checkpoint files
        # @return [Boolean] True if file was removed
        def checkpoint_file_removed?(checkpoint_id, path)
          file_path = checkpoint_file_path(checkpoint_id, path)
          return false unless File.exist?(file_path)

          File.delete(file_path)
          true
        end

        private

        def checkpoint_file_path(checkpoint_id, path)
          File.join(path, "#{checkpoint_id}.json")
        end
      end
    end
  end
end
