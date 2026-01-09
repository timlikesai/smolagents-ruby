# frozen_string_literal: true

require "open3"
require "json"
require "tempfile"

module Smolagents
  # Docker-based multi-language code executor.
  # Provides secure execution for Ruby, Python, JavaScript, and TypeScript.
  #
  # Uses Docker containers for OS-level isolation with:
  # - Network disabled
  # - Memory limits
  # - CPU limits
  # - Read-only filesystem (except /tmp)
  # - No privileged access
  #
  # @example Basic usage
  #   executor = DockerExecutor.new
  #   result = executor.execute("print(2 + 2)", language: :python)
  #   puts result.output
  #
  # @example With custom Docker image
  #   executor = DockerExecutor.new(
  #     images: { ruby: "ruby:3.3-slim" }
  #   )
  class DockerExecutor < Executor
    # Default Docker images for each language.
    DEFAULT_IMAGES = {
      ruby: "ruby:3.3-alpine",
      python: "python:3.12-slim",
      javascript: "node:20-alpine",
      typescript: "node:20-alpine"
    }.freeze

    # Language command templates.
    COMMANDS = {
      ruby: ["ruby", "-e"],
      python: ["python3", "-c"],
      javascript: ["node", "-e"],
      typescript: ["npx", "-y", "tsx", "-e"] # Uses tsx for TypeScript
    }.freeze

    # @param images [Hash<Symbol, String>] custom Docker images per language
    # @param docker_path [String] path to docker binary (default: "docker")
    def initialize(images: {}, docker_path: "docker")
      super()
      @images = DEFAULT_IMAGES.merge(images)
      @docker_path = docker_path
      @tools = {}
      @variables = {}
    end

    # Execute code in Docker container.
    #
    # @param code [String] code to execute
    # @param language [Symbol] :ruby, :python, :javascript, or :typescript
    # @param timeout [Integer] execution timeout in seconds
    # @param memory_mb [Integer] memory limit in MB
    # @param cpu_quota [Integer] CPU quota (100000 = 1 CPU)
    # @param options [Hash] additional options
    # @return [ExecutionResult]
    def execute(code, language:, timeout: 5, memory_mb: 256, cpu_quota: 100_000, **_options)
      # Validate parameters first (raises ArgumentError - not caught)
      validate_execution_params!(code, language)

      language_sym = language.to_sym
      image = @images.fetch(language_sym)
      command = COMMANDS.fetch(language_sym)

      # Prepare code with tool/variable injection
      prepared_code = prepare_code(code, language_sym)

      begin
        # Build docker command
        docker_args = build_docker_args(
          image: image,
          command: command,
          code: prepared_code,
          timeout: timeout,
          memory_mb: memory_mb,
          cpu_quota: cpu_quota
        )

        # Execute in Docker
        stdout, stderr, status = execute_docker(docker_args, timeout)

        if status.success?
          ExecutionResult.new(
            output: parse_output(stdout, language_sym),
            logs: stderr,
            error: nil,
            is_final_answer: false
          )
        else
          ExecutionResult.new(
            output: nil,
            logs: stderr,
            error: "Exit code #{status.exitstatus}: #{stderr}",
            is_final_answer: false
          )
        end
      rescue Timeout::Error
        ExecutionResult.new(
          output: nil,
          logs: "",
          error: "Docker execution timeout after #{timeout} seconds",
          is_final_answer: false
        )
      rescue StandardError => e
        ExecutionResult.new(
          output: nil,
          logs: "",
          error: "Docker error: #{e.message}",
          is_final_answer: false
        )
      end
    end

    def supports?(language)
      @images.key?(language.to_sym)
    end

    private

    # Prepare code with tool and variable injection.
    #
    # @param code [String] original code
    # @param language [Symbol] target language
    # @return [String] prepared code
    def prepare_code(code, _language)
      # For now, just return code as-is
      # TODO: Inject tool/variable definitions based on language
      code
    end

    # Build Docker command arguments.
    #
    # @param image [String] Docker image
    # @param command [Array<String>] language command
    # @param code [String] code to execute
    # @param timeout [Integer] timeout in seconds
    # @param memory_mb [Integer] memory limit
    # @param cpu_quota [Integer] CPU quota
    # @return [Array<String>] docker command arguments
    def build_docker_args(image:, command:, code:, timeout:, memory_mb:, cpu_quota:)
      [
        @docker_path,
        "run",
        "--rm", # Remove container after execution
        "--network=none", # No network access
        "--memory=#{memory_mb}m", # Memory limit
        "--memory-swap=#{memory_mb}m", # No swap
        "--cpu-quota=#{cpu_quota}", # CPU limit
        "--pids-limit=32", # Limit processes (prevent fork bombs)
        "--read-only", # Read-only filesystem
        "--tmpfs=/tmp:rw,noexec,nosuid,size=32m", # Writable /tmp, no execution
        "--security-opt=no-new-privileges", # Prevent privilege escalation
        "--cap-drop=ALL", # Drop all capabilities
        image,
        *command,
        code
      ]
    end

    # Execute Docker command.
    #
    # @param docker_args [Array<String>] docker command arguments
    # @param timeout [Integer] timeout in seconds
    # @return [Array<String, String, Process::Status>] stdout, stderr, status
    def execute_docker(docker_args, timeout)
      Timeout.timeout(timeout + 1) do # Add 1s buffer for Docker overhead
        Open3.capture3(*docker_args)
      end
    end

    # Parse output based on language conventions.
    #
    # @param output [String] raw output
    # @param language [Symbol] language
    # @return [Object] parsed output
    def parse_output(output, _language)
      # Try to parse as JSON first (structured output)
      return JSON.parse(output) if output.start_with?("{", "[")

      # Return trimmed string
      output.strip
    rescue JSON::ParserError
      output.strip
    end
  end
end
