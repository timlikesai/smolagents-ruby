require "open3"

module Smolagents
  module Executors
    class Docker < Executor
      # Container execution and process lifecycle management.
      #
      # Handles running Docker containers via Open3.popen3 with timeout
      # enforcement and graceful process termination.
      module Container
        # Executes a docker command and returns output/status.
        #
        # Uses Open3.popen3 for bidirectional I/O with the Docker process.
        # Reads stdout and stderr concurrently in separate threads.
        #
        # @param docker_args [Array<String>] Docker command line arguments
        # @param timeout [Integer] Timeout in seconds
        # @param env [Hash{String => String}] Environment variables
        # @return [Array(String, String, Process::Status)]
        # @raise [Timeout::Error] If execution exceeds timeout
        # @api private
        def execute_docker(docker_args, timeout, env: safe_environment)
          Open3.popen3(env, *docker_args, pgroup: true, unsetenv_others: true) do |stdin, stdout, stderr, wait_thread|
            stdin.close
            wait_for_completion(stdout, stderr, wait_thread, timeout)
          end
        end

        private

        # Waits for Docker process to complete, enforcing timeout.
        #
        # @param stdout [IO] Stdout stream
        # @param stderr [IO] Stderr stream
        # @param wait_thread [Thread] Process wait thread
        # @param timeout [Integer] Timeout in seconds
        # @return [Array(String, String, Process::Status)]
        # @raise [Timeout::Error] If process exceeds timeout
        # @api private
        def wait_for_completion(stdout, stderr, wait_thread, timeout)
          stdout_reader = Thread.new { stdout.read }
          stderr_reader = Thread.new { stderr.read }
          return [stdout_reader.value, stderr_reader.value, wait_thread.value] if wait_thread.join(timeout + 1)

          terminate_process(wait_thread)
        end

        # Terminates a timed-out Docker process.
        #
        # Sends TERM signal first, then KILL if process doesn't exit.
        # Raises Timeout::Error after termination attempt.
        #
        # @param wait_thread [Thread] Process wait thread with pid
        # @raise [Timeout::Error] Always raised after termination
        # @api private
        def terminate_process(wait_thread)
          Process.kill("TERM", -wait_thread.pid)
          wait_thread.join(1)
          Process.kill("KILL", -wait_thread.pid) unless wait_thread.join(0)
        rescue Errno::ESRCH
          # Process already exited
        ensure
          raise Timeout::Error, "execution expired"
        end
      end
    end
  end
end
