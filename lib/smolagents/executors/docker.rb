require "open3"
require "json"

module Smolagents
  module Executors
    # Docker-based code executor for multi-language support.
    #
    # Docker executes agent-generated code in isolated containers with strict
    # resource limits. This executor supports multiple languages: Ruby, Python,
    # JavaScript, and TypeScript.
    #
    # == Execution Model
    #
    # Each code execution runs in a fresh container using Open3.popen3. The
    # container is removed automatically (--rm). Code is passed as a single
    # string argument to the language interpreter.
    #
    # == Language Support
    #
    # - Ruby: ruby:3.3-alpine with "ruby -e"
    # - Python: python:3.12-slim with "python3 -c"
    # - JavaScript: node:20-alpine with "node -e"
    # - TypeScript: node:20-alpine with "npx -y tsx -e"
    #
    # Custom images can be specified via the images parameter.
    #
    # == Security Features
    #
    # - Network isolation (--network=none)
    # - Memory limits (--memory, --memory-swap)
    # - CPU quotas (--cpu-quota controls milliseconds per period)
    # - Read-only filesystem (--read-only)
    # - Dropped capabilities (--cap-drop=ALL)
    # - No new privileges (--security-opt=no-new-privileges)
    # - PID limits (--pids-limit=32)
    # - Temporary filesystem (--tmpfs=/tmp, noexec, nosuid, 32m limit)
    # - Sanitized environment (only safe variables, no secrets/tokens/keys)
    #
    # == Output Parsing
    #
    # Stdout is automatically parsed:
    # - If output starts with "{" or "[", parsed as JSON
    # - Otherwise returned as string (whitespace trimmed)
    # - JSON parse errors fall back to string
    #
    # @example Basic execution
    #   executor = Executors::Docker.new
    #   result = executor.execute("puts 'Hello'", language: :ruby)
    #   result.output  # => "Hello"
    #   result.success?  # => true
    #
    # @example Multi-language support
    #   executor = Executors::Docker.new
    #   ruby_result = executor.execute("[1,2,3].sum", language: :ruby)
    #   python_result = executor.execute("print(sum([1,2,3]))", language: :python)
    #
    # @example Custom resource limits
    #   executor = Executors::Docker.new
    #   result = executor.execute(
    #     "sleep(100)",
    #     language: :python,
    #     timeout: 5,
    #     memory_mb: 128,
    #     cpu_quota: 50_000
    #   )
    #
    # @example Custom images
    #   executor = Executors::Docker.new(
    #     images: { ruby: "ruby:3.4-alpine", python: "python:3.11-slim" }
    #   )
    #
    # @see Executor Base class
    # @see DEFAULT_IMAGES For default container images
    # @see COMMANDS For language-specific interpreters
    class Docker < Executor
      # Default container images for each supported language
      #
      # @return [Hash{Symbol => String}] Language to Docker image mapping
      DEFAULT_IMAGES = {
        ruby: "ruby:3.3-alpine", python: "python:3.12-slim",
        javascript: "node:20-alpine", typescript: "node:20-alpine"
      }.freeze

      # Interpreter commands for each language
      #
      # Maps language to command array: [executable, *args]
      # The args typically include a flag to read code from argument (vs stdin)
      #
      # @return [Hash{Symbol => Array<String>}] Language to command mapping
      COMMANDS = {
        ruby: ["ruby", "-e"], python: ["python3", "-c"],
        javascript: ["node", "-e"], typescript: ["npx", "-y", "tsx", "-e"]
      }.freeze

      # Safe environment variables to pass to Docker.
      #
      # Only these environment variables are forwarded to the container.
      # API keys, tokens, passwords, and other sensitive data are never passed.
      # This is a whitelist - only explicitly allowed variables are forwarded.
      #
      # @return [Array<String>] Variable names to forward (never API keys, tokens, etc.)
      SAFE_ENV_VARS = %w[
        PATH HOME USER LANG LC_ALL LC_CTYPE TZ TERM
      ].freeze

      # Patterns identifying sensitive environment variables.
      #
      # Environment variables matching any of these patterns are never forwarded
      # to Docker containers, even if listed in SAFE_ENV_VARS. This provides
      # defense in depth against accidental secret leakage.
      #
      # @return [Array<Regexp>] Patterns for sensitive variable names
      SENSITIVE_PATTERNS = [
        /api[_-]?key/i,
        /secret/i,
        /token/i,
        /password/i,
        /credential/i,
        /auth/i,
        /private[_-]?key/i,
        /access[_-]?key/i
      ].freeze

      # Creates a new Docker executor.
      #
      # Initializes the executor with Docker image and path configuration. Images
      # can be overridden from the defaults, and the docker executable path can
      # be customized for non-standard Docker installations.
      #
      # @param images [Hash{Symbol => String}] Custom Docker images by language.
      #   Merged with DEFAULT_IMAGES, so only override specific languages.
      # @param docker_path [String] Path to docker executable (default: "docker")
      # @return [void]
      # @example
      #   # Use all defaults
      #   executor = Executors::Docker.new
      #
      # @example Override specific images
      #   executor = Executors::Docker.new(
      #     images: { ruby: "ruby:3.4-alpine", python: "python:3.11-slim" }
      #   )
      #
      # @example Custom docker path (for non-standard installations)
      #   executor = Executors::Docker.new(docker_path: "/usr/local/bin/docker")
      def initialize(images: {}, docker_path: "docker")
        super()
        @images = DEFAULT_IMAGES.merge(images)
        @docker_path = docker_path
        @tools = {}
        @variables = {}
      end

      # Executes code in a Docker container.
      #
      # Runs code in an isolated container with strict resource limits. The container
      # is automatically created, run, and removed.
      #
      # == Execution Flow
      # 1. Validate code and language support
      # 2. Build Docker command arguments with resource limits
      # 3. Execute docker run with Open3.popen3
      # 4. Capture stdout and stderr
      # 5. Parse JSON output or return as string
      # 6. Handle timeout/errors gracefully
      #
      # == Output Parsing
      # - JSON if output starts with "{" or "["
      # - Otherwise string (trimmed whitespace)
      # - JSON parse errors fall back to string representation
      #
      # @param code [String] Source code to execute
      # @param language [Symbol] Programming language (:ruby, :python, :javascript, :typescript)
      # @param timeout [Integer] Maximum execution time in seconds (default: 5)
      # @param memory_mb [Integer] Memory limit in MB (default: 256)
      # @param cpu_quota [Integer] CPU quota (microseconds per period, default: 100,000)
      # @param options [Hash] Additional options (ignored)
      # @return [ExecutionResult] Result with output, logs, and any error
      # @example
      #   executor = Executors::Docker.new
      #   result = executor.execute(
      #     "puts [1,2,3].sum",
      #     language: :ruby,
      #     timeout: 10,
      #     memory_mb: 512
      #   )
      #   result.output  # => 6
      # @see COMMANDS For supported languages
      # @see execute_docker For low-level Docker interaction
      def execute(code, language:, timeout: 5, memory_mb: 256, cpu_quota: 100_000, **_options)
        Instrumentation.instrument("smolagents.executor.execute", executor_class: self.class.name, language:) do
          validate_execution_params!(code, language)
          run_in_docker(code, language.to_sym, timeout:, memory_mb:, cpu_quota:)
        rescue Timeout::Error then build_result(error: "Docker execution timeout after #{timeout} seconds")
        rescue KeyError, RuntimeError => e then build_result(error: "Docker error: #{e.message}")
        end
      end

      def run_in_docker(code, language_sym, timeout:, memory_mb:, cpu_quota:)
        docker_args = build_docker_args(image: @images.fetch(language_sym), command: COMMANDS.fetch(language_sym),
                                        code: prepare_code(code, language_sym), timeout:, memory_mb:, cpu_quota:)
        stdout, stderr, status = execute_docker(docker_args, timeout)
        build_execution_result(stdout, stderr, status)
      end

      def build_execution_result(stdout, stderr, status)
        return build_result(output: parse_output(stdout), logs: stderr) if status.success?

        build_result(logs: stderr, error: "Exit code #{status.exitstatus}: #{stderr}")
      end

      # Checks if Docker executor supports a language.
      #
      # @param language [Symbol] Language to check (:ruby, :python, :javascript, :typescript)
      # @return [Boolean] True if language is in the configured images
      # @example
      #   executor = Executors::Docker.new
      #   executor.supports?(:ruby)    # => true
      #   executor.supports?(:python)  # => true
      #   executor.supports?(:rust)    # => false
      def supports?(language) = @images.key?(language.to_sym)

      private

      # Prepares code for execution in Docker container.
      #
      # Can be overridden in subclasses for language-specific preprocessing.
      # Currently a passthrough, but exists for extension points.
      #
      # @param code [String] Source code
      # @param _language [Symbol] Language (for future use)
      # @return [String] Code ready for execution
      # @api private
      def prepare_code(code, _language) = code

      # Builds Docker command-line arguments.
      #
      # Constructs the full docker run command with all security and resource
      # limit options. The resulting array is passed to Open3.popen3.
      #
      # == Security Options
      # - --rm: Remove container after execution
      # - --network=none: No network access
      # - --read-only: Read-only filesystem
      # - --cap-drop=ALL: Drop all Linux capabilities
      # - --security-opt=no-new-privileges: Prevent privilege escalation
      # - --pids-limit=32: Limit number of processes
      # - --tmpfs=/tmp: Temporary filesystem (noexec, nosuid, 32m limit)
      #
      # == Resource Limits
      # - --memory: Memory limit (MB)
      # - --memory-swap: Swap limit (same as memory for no swap)
      # - --cpu-quota: CPU quota (microseconds per period)
      #
      # @param image [String] Docker image name (e.g., "ruby:3.3-alpine")
      # @param command [Array<String>] Interpreter command (e.g., ["ruby", "-e"])
      # @param code [String] Source code to execute
      # @param timeout [Integer] Timeout in seconds (for building args)
      # @param memory_mb [Integer] Memory limit in MB
      # @param cpu_quota [Integer] CPU quota value
      # @return [Array<String>] Complete docker run command line
      # @api private
      def build_docker_args(image:, command:, code:, _timeout:, memory_mb:, cpu_quota:)
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
      # Creates an environment variable hash for passing to Docker. Uses a
      # whitelist approach (SAFE_ENV_VARS) combined with pattern-based filtering
      # (SENSITIVE_PATTERNS) to prevent secret leakage.
      #
      # This provides defense in depth:
      # 1. Only whitelisted variable names are included
      # 2. Whitelisted variables matching sensitive patterns are dropped
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
      # Uses SENSITIVE_PATTERNS to identify variables that should never be
      # passed to containers (API keys, tokens, passwords, etc.).
      #
      # @param key [String, Symbol] Environment variable name
      # @return [Boolean] True if name matches a sensitive pattern
      # @api private
      def sensitive_key?(key)
        SENSITIVE_PATTERNS.any? { |pattern| key.to_s.match?(pattern) }
      end

      # Executes a docker command and returns output/status.
      #
      # Uses Open3.popen3 for bidirectional I/O with the Docker process.
      # Reads stdout and stderr concurrently in separate threads to prevent
      # deadlock. Enforces timeout by terminating the process if it exceeds
      # the deadline.
      #
      # == Timeout Handling
      # 1. Use wait_thread.join(timeout + 1) to wait for completion
      # 2. If not done, send TERM signal
      # 3. If TERM doesn't work, send KILL signal
      # 4. Raise Timeout::Error if process doesn't exit
      #
      # @param docker_args [Array<String>] Docker command line arguments
      # @param timeout [Integer] Timeout in seconds
      # @return [Array(String, String, Process::Status)]
      #   - stdout: captured output from container
      #   - stderr: captured errors from container
      #   - status: exit status object
      # @raise [Timeout::Error] If execution exceeds timeout
      # @api private
      def execute_docker(docker_args, timeout)
        Open3.popen3(safe_environment, *docker_args,
                     pgroup: true, unsetenv_others: true) do |stdin, stdout, stderr, wait_thread|
          stdin.close
          wait_for_docker(stdout, stderr, wait_thread, timeout)
        end
      end

      def wait_for_docker(stdout, stderr, wait_thread, timeout)
        stdout_reader = Thread.new { stdout.read }
        stderr_reader = Thread.new { stderr.read }
        return [stdout_reader.value, stderr_reader.value, wait_thread.value] if wait_thread.join(timeout + 1)

        terminate_process(wait_thread)
      end

      def terminate_process(wait_thread)
        Process.kill("TERM", -wait_thread.pid)
        wait_thread.join(1)
        Process.kill("KILL", -wait_thread.pid) unless wait_thread.join(0)
      rescue Errno::ESRCH
      ensure
        raise Timeout::Error, "execution expired"
      end

      # Parses Docker output.
      #
      # Automatically detects and parses JSON output if the output starts with
      # "{" or "[". Otherwise returns the output as a string (trimmed).
      #
      # JSON parse errors gracefully fall back to string representation.
      #
      # @param output [String] Output from docker container
      # @param _language [Symbol] Language (for future use)
      # @return [Object] Parsed JSON or string
      # @api private
      def parse_output(output, _language = nil)
        return JSON.parse(output) if output.start_with?("{", "[")

        output.strip
      rescue JSON::ParserError
        output.strip
      end

      # Builds an ExecutionResult for Docker execution.
      #
      # Creates result with no is_final_answer tracking (Docker doesn't support
      # final_answer() calls).
      #
      # @param output [Object] Parsed output from container
      # @param logs [String] stderr output from container
      # @param error [String, nil] Error message if execution failed
      # @return [ExecutionResult] Result object
      # @api private
      def build_result(output: nil, logs: "", error: nil)
        ExecutionResult.new(output:, logs:, error:, is_final_answer: false)
      end
    end
  end
end
