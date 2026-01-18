require_relative "docker/command_builder"
require_relative "docker/container"
require_relative "docker/output_parser"

module Smolagents
  module Executors
    # Docker-based code executor for multi-language support.
    #
    # Executes agent-generated code in isolated containers with strict
    # resource limits. Supports Ruby, Python, JavaScript, and TypeScript.
    #
    # @example Basic usage
    #   executor = Smolagents::Executors::Docker.new
    #   executor.supports?(:ruby)  #=> true
    #
    # @note Requires Docker to be installed and running
    # @see Executor Base class
    class Docker < Executor
      include CommandBuilder
      include Container
      include OutputParser

      # Default container images for each supported language.
      DEFAULT_IMAGES = {
        ruby: "ruby:3.3-alpine", python: "python:3.12-slim",
        javascript: "node:20-alpine", typescript: "node:20-alpine"
      }.freeze

      # Interpreter commands for each language.
      COMMANDS = {
        ruby: ["ruby", "-e"], python: ["python3", "-c"],
        javascript: ["node", "-e"], typescript: ["npx", "-y", "tsx", "-e"]
      }.freeze

      # Safe environment variables to pass to Docker.
      SAFE_ENV_VARS = %w[PATH HOME USER LANG LC_ALL LC_CTYPE TZ TERM].freeze

      # Patterns identifying sensitive environment variables.
      SENSITIVE_PATTERNS = [
        /api[_-]?key/i, /secret/i, /token/i, /password/i,
        /credential/i, /auth/i, /private[_-]?key/i, /access[_-]?key/i
      ].freeze

      # @param images [Hash{Symbol => String}] Custom Docker images by language
      # @param docker_path [String] Path to docker executable
      def initialize(images: {}, docker_path: "docker")
        super()
        @images = DEFAULT_IMAGES.merge(images)
        @docker_path = docker_path
        @tools = {}
        @variables = {}
      end

      # Executes code in a Docker container with strict resource limits.
      #
      # @param code [String] Source code to execute
      # @param language [Symbol] Programming language
      # @param timeout [Integer] Maximum execution time in seconds
      # @param memory_mb [Integer] Memory limit in MB
      # @param cpu_quota [Integer] CPU quota (microseconds per period)
      # @return [ExecutionResult] Result with output, logs, and any error
      def execute(code, language:, timeout: 5, memory_mb: 256, cpu_quota: 100_000, **_options)
        Instrumentation.instrument("smolagents.executor.execute", executor_class: self.class.name, language:) do
          validate_execution_params!(code, language)
          run_in_docker(code, language.to_sym, timeout:, memory_mb:, cpu_quota:)
        rescue Timeout::Error
          build_result(error: "Docker execution timeout after #{timeout} seconds")
        rescue KeyError, RuntimeError => e
          build_result(error: "Docker error: #{e.message}")
        end
      end

      # @param language [Symbol] Language to check
      # @return [Boolean] True if language is in configured images
      def supports?(language) = @images.key?(language.to_sym)

      private

      def run_in_docker(code, language_sym, timeout:, memory_mb:, cpu_quota:)
        docker_args = build_docker_args(
          image: @images.fetch(language_sym),
          command: COMMANDS.fetch(language_sym),
          code: prepare_code(code, language_sym),
          memory_mb:, cpu_quota:
        )
        stdout, stderr, status = execute_docker(docker_args, timeout)
        build_execution_result(stdout, stderr, status)
      end

      def prepare_code(code, _language) = code
    end
  end
end
