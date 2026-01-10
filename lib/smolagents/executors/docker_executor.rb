# frozen_string_literal: true

require "open3"
require "json"

module Smolagents
  # Docker-based multi-language code executor with OS-level isolation.
  class DockerExecutor < Executor
    DEFAULT_IMAGES = {
      ruby: "ruby:3.3-alpine", python: "python:3.12-slim",
      javascript: "node:20-alpine", typescript: "node:20-alpine"
    }.freeze

    COMMANDS = {
      ruby: ["ruby", "-e"], python: ["python3", "-c"],
      javascript: ["node", "-e"], typescript: ["npx", "-y", "tsx", "-e"]
    }.freeze

    def initialize(images: {}, docker_path: "docker")
      super()
      @images = DEFAULT_IMAGES.merge(images)
      @docker_path = docker_path
      @tools = {}
      @variables = {}
    end

    def execute(code, language:, timeout: 5, memory_mb: 256, cpu_quota: 100_000, **_options)
      validate_execution_params!(code, language)
      language_sym = language.to_sym

      docker_args = build_docker_args(
        image: @images.fetch(language_sym), command: COMMANDS.fetch(language_sym),
        code: prepare_code(code, language_sym), timeout: timeout, memory_mb: memory_mb, cpu_quota: cpu_quota
      )

      stdout, stderr, status = execute_docker(docker_args, timeout)

      if status.success?
        build_result(output: parse_output(stdout), logs: stderr)
      else
        build_result(logs: stderr, error: "Exit code #{status.exitstatus}: #{stderr}")
      end
    rescue Timeout::Error
      build_result(error: "Docker execution timeout after #{timeout} seconds")
    rescue KeyError, RuntimeError => e
      build_result(error: "Docker error: #{e.message}")
    end

    def supports?(language) = @images.key?(language.to_sym)

    private

    def prepare_code(code, _language) = code

    def build_docker_args(image:, command:, code:, timeout:, memory_mb:, cpu_quota:)
      [
        @docker_path, "run", "--rm", "--network=none",
        "--memory=#{memory_mb}m", "--memory-swap=#{memory_mb}m",
        "--cpu-quota=#{cpu_quota}", "--pids-limit=32", "--read-only",
        "--tmpfs=/tmp:rw,noexec,nosuid,size=32m",
        "--security-opt=no-new-privileges", "--cap-drop=ALL",
        image, *command, code
      ]
    end

    def execute_docker(docker_args, timeout)
      Timeout.timeout(timeout + 1) { Open3.capture3(*docker_args) }
    end

    def parse_output(output, _language = nil)
      return JSON.parse(output) if output.start_with?("{", "[")
      output.strip
    rescue JSON::ParserError
      output.strip
    end

    def build_result(output: nil, logs: "", error: nil)
      ExecutionResult.new(output: output, logs: logs, error: error, is_final_answer: false)
    end
  end
end
