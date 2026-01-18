module Smolagents
  module Executors
    class Docker < Executor
      # Docker command-line argument construction.
      #
      # Builds secure docker run commands with resource limits,
      # security options, and environment filtering.
      module CommandBuilder
        # Builds Docker command-line arguments.
        #
        # Constructs docker run command with security and resource limits:
        # - --rm: Remove container after execution
        # - --network=none: No network access
        # - --read-only: Read-only filesystem
        # - --cap-drop=ALL: Drop all Linux capabilities
        # - --security-opt=no-new-privileges: Prevent escalation
        # - --pids-limit=32: Limit process count
        # - --tmpfs=/tmp: Writable temp space (noexec, 32m)
        #
        # @param image [String] Docker image name
        # @param command [Array<String>] Interpreter command
        # @param code [String] Source code to execute
        # @param memory_mb [Integer] Memory limit in MB
        # @param cpu_quota [Integer] CPU quota value
        # @return [Array<String>] Complete docker run command
        # @api private
        def build_docker_args(image:, command:, code:, memory_mb:, cpu_quota:, **)
          [
            @docker_path, "run", "--rm", "--network=none",
            "--memory=#{memory_mb}m", "--memory-swap=#{memory_mb}m",
            "--cpu-quota=#{cpu_quota}", "--pids-limit=32", "--read-only",
            "--tmpfs=/tmp:rw,noexec,nosuid,size=32m",
            "--security-opt=no-new-privileges", "--cap-drop=ALL",
            image, *command, code
          ]
        end

        # Builds a sanitized environment for Docker execution.
        #
        # Uses whitelist approach (SAFE_ENV_VARS) combined with pattern-based
        # filtering (SENSITIVE_PATTERNS) to prevent secret leakage.
        #
        # @return [Hash{String => String}] Safe environment for Docker
        # @api private
        def safe_environment
          SAFE_ENV_VARS.each_with_object({}) do |var, env|
            env[var] = ENV.fetch(var, nil) if ENV.key?(var) && !sensitive_key?(var)
          end
        end

        # Checks if an environment variable name looks sensitive.
        #
        # @param key [String, Symbol] Environment variable name
        # @return [Boolean] True if name matches a sensitive pattern
        # @api private
        def sensitive_key?(key)
          SENSITIVE_PATTERNS.any? { |pattern| key.to_s.match?(pattern) }
        end
      end
    end
  end
end
