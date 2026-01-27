module Smolagents
  module Concerns
    module Checkpoints
      # Serialize/deserialize checkpoints to JSON-safe formats.
      #
      # Handles nested types (ChatMessage, Goal, WorkingMemoryState) by
      # recursively converting to/from hash representations.
      #
      # @example Serializing
      #   data = serialize_checkpoint(checkpoint)
      #   JSON.generate(data)  # Safe for storage
      #
      # @example Deserializing
      #   data = JSON.parse(json, symbolize_names: true)
      #   checkpoint = deserialize_checkpoint(data)
      module Serialization
        # Serialize a checkpoint to a JSON-compatible hash.
        # @param checkpoint [Types::Checkpoint] The checkpoint to serialize
        # @return [Hash] JSON-serializable hash
        def serialize_checkpoint(checkpoint) = checkpoint.to_h

        # Deserialize a checkpoint from a hash.
        # @param data [Hash] Serialized checkpoint data
        # @return [Types::Checkpoint] Reconstructed checkpoint
        def deserialize_checkpoint(data) = Types::Checkpoint.from_h(symbolize_keys(data))

        private

        def symbolize_keys(hash)
          return hash unless hash.is_a?(Hash)

          hash.each_with_object({}) do |(key, value), result|
            sym_key = key.is_a?(String) ? key.to_sym : key
            result[sym_key] = case value
                              when Hash then symbolize_keys(value)
                              when Array then value.map { |v| symbolize_keys(v) }
                              else value
                              end
          end
        end
      end
    end
  end
end
