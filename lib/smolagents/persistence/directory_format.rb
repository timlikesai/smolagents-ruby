require "json"
require "yaml"

module Smolagents
  module Persistence
    # Handles saving and loading agents as directory structures.
    #
    # DirectoryFormat provides the file system persistence layer for agents.
    # It creates human-readable, git-friendly directory structures that can
    # be easily inspected and version controlled.
    #
    # Directory structure created by save:
    #   path/
    #   ├── agent.json              # Main manifest
    #   ├── tools/
    #   │   └── *.json              # Tool manifests
    #   └── managed_agents/
    #       └── agent_name/         # Recursive structure
    #           └── ...
    #
    # @example Saving an agent
    #   DirectoryFormat.save(agent, "./my_agent")
    #
    # @example Loading an agent
    #   agent = DirectoryFormat.load("./my_agent", model: my_model)
    #
    # @see Serializable For the high-level save/load API
    # @see AgentManifest For the manifest structure
    module DirectoryFormat
      extend self

      # @return [String] Filename for the main agent manifest
      AGENT_FILE = "agent.json".freeze

      # @return [String] Directory name for tool manifests
      TOOLS_DIR = "tools".freeze

      # @return [String] Directory name for managed agent subdirectories
      MANAGED_AGENTS_DIR = "managed_agents".freeze

      # Saves an agent to a directory.
      #
      # Creates the directory if it doesn't exist and writes:
      # - agent.json with the main manifest
      # - tools/ directory with individual tool manifests
      # - managed_agents/ with recursively saved sub-agents
      #
      # @param agent [Agent] The agent to save
      # @param path [String, Pathname] Directory path to save to
      # @param metadata [Hash] Additional metadata to include
      # @return [Pathname] The path where agent was saved
      def save(agent, path, metadata: {})
        path = Pathname(path)
        path.mkpath

        manifest = AgentManifest.from_agent(agent, metadata:)

        write_manifest(path, manifest)
        write_tools(path, manifest.tools)
        write_managed_agents(path, agent, manifest.managed_agents)

        path
      end

      # Loads an agent from a saved directory.
      #
      # Reconstructs an agent from its manifest and tool files.
      # The model must be provided since API keys are never stored.
      #
      # @param path [String, Pathname] Directory path to load from
      # @param model [Model] Model instance (required)
      # @param api_key [String, nil] API key for tool initialization
      # @param overrides [Hash] Settings to override from manifest
      # @return [Agent] Reconstructed agent instance
      # @raise [Errno::ENOENT] If directory or manifest doesn't exist
      # @raise [MissingModelError] If model is not provided
      # @raise [InvalidManifestError] If manifest JSON is invalid
      def load(path, model: nil, api_key: nil, **overrides)
        path = Pathname(path)

        raise Errno::ENOENT, "Agent directory not found: #{path}" unless path.exist?
        raise Errno::ENOENT, "Agent manifest not found: #{path / AGENT_FILE}" unless (path / AGENT_FILE).exist?

        manifest = read_manifest(path)
        manifest.instantiate(model:, api_key:, **overrides)
      end

      private

      # Writes the main agent manifest JSON file.
      # @api private
      def write_manifest(path, manifest)
        (path / AGENT_FILE).write(JSON.pretty_generate(manifest.to_h))
      end

      # Writes individual tool manifest files to the tools directory.
      # @api private
      def write_tools(path, tools)
        return if tools.empty?

        tools_dir = path / TOOLS_DIR
        tools_dir.mkpath

        tools.each do |tool|
          (tools_dir / "#{tool.name}.json").write(JSON.pretty_generate(tool.to_h))
        end
      end

      # Recursively saves managed agents to subdirectories.
      # @api private
      def write_managed_agents(path, agent, managed_agent_manifests)
        return if managed_agent_manifests.empty?

        managed_agents_dir = path / MANAGED_AGENTS_DIR
        managed_agents_dir.mkpath

        agent.managed_agents.each do |name, managed_agent_tool|
          save(managed_agent_tool.agent, managed_agents_dir / name)
        end
      end

      # Reads and parses the agent manifest from disk.
      # @api private
      # @raise [InvalidManifestError] If JSON parsing fails
      def read_manifest(path)
        json = JSON.parse((path / AGENT_FILE).read)
        AgentManifest.from_h(json)
      rescue JSON::ParserError => e
        raise InvalidManifestError, "Invalid JSON in #{path / AGENT_FILE}: #{e.message}"
      end
    end
  end
end
