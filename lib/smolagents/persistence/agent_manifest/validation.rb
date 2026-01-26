module Smolagents
  module Persistence
    # Validates agent manifest data.
    module AgentManifestValidation
      module_function

      # Validates manifest hash data.
      # @param data [Hash] The manifest data to validate
      # @raise [VersionMismatchError] If manifest version is unsupported
      # @raise [InvalidManifestError] If required fields are missing
      def validate!(data)
        validate_required_fields!(data)
        validate_version!(data[:version])
      end

      # Validates that agent class is in the allowlist.
      # @param agent_class [String] The agent class name
      # @raise [UntrustedClassError] If agent_class is not allowed
      def validate_agent_class!(agent_class)
        return if AgentManifestConstants::ALLOWED_CLASSES.include?(agent_class)

        raise UntrustedClassError.new(agent_class, AgentManifestConstants::ALLOWED_CLASSES.to_a)
      end

      private_class_method def self.validate_required_fields!(data)
        missing = AgentManifestConstants::REQUIRED_FIELDS.reject { data[it] }
        return if missing.empty?

        raise(InvalidManifestError, missing.map { "missing #{it}" })
      end

      private_class_method def self.validate_version!(version)
        return if version == AgentManifestConstants::VERSION

        raise VersionMismatchError.new(version, AgentManifestConstants::VERSION)
      end
    end
  end
end
