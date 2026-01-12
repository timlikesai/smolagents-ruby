require "json"
require "yaml"

module Smolagents
  module Persistence
    module DirectoryFormat
      extend self

      AGENT_FILE = "agent.json".freeze
      TOOLS_DIR = "tools".freeze
      MANAGED_AGENTS_DIR = "managed_agents".freeze

      def save(agent, path, metadata: {})
        path = Pathname(path)
        path.mkpath

        manifest = AgentManifest.from_agent(agent, metadata:)

        write_manifest(path, manifest)
        write_tools(path, manifest.tools)
        write_managed_agents(path, agent, manifest.managed_agents)

        path
      end

      def load(path, model: nil, api_key: nil, **overrides)
        path = Pathname(path)

        raise Errno::ENOENT, "Agent directory not found: #{path}" unless path.exist?
        raise Errno::ENOENT, "Agent manifest not found: #{path / AGENT_FILE}" unless (path / AGENT_FILE).exist?

        manifest = read_manifest(path)
        manifest.instantiate(model:, api_key:, **overrides)
      end

      private

      def write_manifest(path, manifest)
        (path / AGENT_FILE).write(JSON.pretty_generate(manifest.to_h))
      end

      def write_tools(path, tools)
        return if tools.empty?

        tools_dir = path / TOOLS_DIR
        tools_dir.mkpath

        tools.each do |tool|
          (tools_dir / "#{tool.name}.json").write(JSON.pretty_generate(tool.to_h))
        end
      end

      def write_managed_agents(path, agent, managed_agent_manifests)
        return if managed_agent_manifests.empty?

        managed_agents_dir = path / MANAGED_AGENTS_DIR
        managed_agents_dir.mkpath

        agent.managed_agents.each do |name, managed_agent_tool|
          save(managed_agent_tool.agent, managed_agents_dir / name)
        end
      end

      def read_manifest(path)
        json = JSON.parse((path / AGENT_FILE).read)
        AgentManifest.from_h(json)
      rescue JSON::ParserError => e
        raise InvalidManifestError, "Invalid JSON in #{path / AGENT_FILE}: #{e.message}"
      end
    end
  end
end
