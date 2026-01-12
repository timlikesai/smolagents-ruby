module Smolagents
  module Persistence
    module Serializable
      def self.included(base)
        base.extend(ClassMethods)
      end

      def save(path, metadata: {})
        DirectoryFormat.save(self, path, metadata:)
      end

      def to_manifest(metadata: {})
        AgentManifest.from_agent(self, metadata:)
      end

      module ClassMethods
        def from_folder(path, model: nil, api_key: nil, **overrides)
          DirectoryFormat.load(path, model:, api_key:, **overrides)
        end

        def from_manifest(manifest, model: nil, api_key: nil, **overrides)
          manifest.instantiate(model:, api_key:, **overrides)
        end
      end
    end
  end
end
