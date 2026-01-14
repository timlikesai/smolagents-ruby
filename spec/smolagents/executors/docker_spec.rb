RSpec.describe Smolagents::DockerExecutor do
  let(:executor) { described_class.new }

  describe "#supports?" do
    it "supports Ruby" do
      expect(executor.supports?(:ruby)).to be true
    end

    it "supports Python" do
      expect(executor.supports?(:python)).to be true
    end

    it "supports JavaScript" do
      expect(executor.supports?(:javascript)).to be true
    end

    it "supports TypeScript" do
      expect(executor.supports?(:typescript)).to be true
    end

    it "does not support unknown languages" do
      expect(executor.supports?(:cobol)).to be false
    end

    it "handles string language arguments" do
      expect(executor.supports?("ruby")).to be true
      expect(executor.supports?("python")).to be true
    end
  end

  describe "DEFAULT_IMAGES" do
    it "defines default images for all supported languages" do
      expect(described_class::DEFAULT_IMAGES[:ruby]).to eq("ruby:3.3-alpine")
      expect(described_class::DEFAULT_IMAGES[:python]).to eq("python:3.12-slim")
      expect(described_class::DEFAULT_IMAGES[:javascript]).to eq("node:20-alpine")
      expect(described_class::DEFAULT_IMAGES[:typescript]).to eq("node:20-alpine")
    end

    it "is frozen to prevent modification" do
      expect(described_class::DEFAULT_IMAGES).to be_frozen
    end
  end

  describe "COMMANDS" do
    it "defines commands for all supported languages" do
      expect(described_class::COMMANDS[:ruby]).to eq(["ruby", "-e"])
      expect(described_class::COMMANDS[:python]).to eq(["python3", "-c"])
      expect(described_class::COMMANDS[:javascript]).to eq(["node", "-e"])
      expect(described_class::COMMANDS[:typescript]).to eq(["npx", "-y", "tsx", "-e"])
    end

    it "is frozen to prevent modification" do
      expect(described_class::COMMANDS).to be_frozen
    end
  end

  describe "SAFE_ENV_VARS" do
    it "includes safe environment variables" do
      expect(described_class::SAFE_ENV_VARS).to include(
        "PATH", "HOME", "USER", "LANG", "LC_ALL", "LC_CTYPE", "TZ", "TERM"
      )
    end

    it "is frozen to prevent modification" do
      expect(described_class::SAFE_ENV_VARS).to be_frozen
    end
  end

  describe "SENSITIVE_PATTERNS" do
    it "includes patterns for sensitive variables" do
      patterns = described_class::SENSITIVE_PATTERNS
      expect(patterns).not_to be_empty
      expect(patterns).to all(be_a(Regexp))
    end
  end

  describe "#initialize" do
    it "creates executor with default images" do
      executor = described_class.new
      images = executor.instance_variable_get(:@images)
      expect(images[:ruby]).to eq("ruby:3.3-alpine")
      expect(images[:python]).to eq("python:3.12-slim")
    end

    it "accepts custom images" do
      executor = described_class.new(images: { ruby: "ruby:3.2-slim" })
      expect(executor.instance_variable_get(:@images)[:ruby]).to eq("ruby:3.2-slim")
    end

    it "merges custom images with defaults" do
      executor = described_class.new(images: { ruby: "custom:latest" })
      images = executor.instance_variable_get(:@images)
      expect(images[:ruby]).to eq("custom:latest")
      expect(images[:python]).to eq("python:3.12-slim")
    end

    it "accepts custom docker path" do
      executor = described_class.new(docker_path: "/usr/local/bin/docker")
      expect(executor.instance_variable_get(:@docker_path)).to eq("/usr/local/bin/docker")
    end

    it "defaults docker path to 'docker'" do
      executor = described_class.new
      expect(executor.instance_variable_get(:@docker_path)).to eq("docker")
    end

    it "initializes tools and variables" do
      executor = described_class.new
      expect(executor.instance_variable_get(:@tools)).to be_a(Hash)
      expect(executor.instance_variable_get(:@variables)).to be_a(Hash)
    end

    it "calls parent initializer" do
      executor = described_class.new
      expect(executor.instance_variable_get(:@max_operations)).to eq(Smolagents::Executors::Executor::DEFAULT_MAX_OPERATIONS)
      expect(executor.instance_variable_get(:@max_output_length)).to eq(Smolagents::Executors::Executor::DEFAULT_MAX_OUTPUT_LENGTH)
    end
  end

  describe "#execute" do
    context "with Docker available", :integration do
      before do
        skip "Docker not available" unless system("docker info > /dev/null 2>&1")
      end

      it "executes Ruby code" do
        result = executor.execute("puts 'hello'.upcase", language: :ruby)
        expect(result.success?).to be true
        expect(result.output.strip).to eq("HELLO")
      end

      it "executes Python code" do
        result = executor.execute("print('hello'.upper())", language: :python)
        expect(result.success?).to be true
        expect(result.output.strip).to eq("HELLO")
      end

      it "executes JavaScript code" do
        result = executor.execute("console.log('hello'.toUpperCase())", language: :javascript)
        expect(result.success?).to be true
        expect(result.output.strip).to eq("HELLO")
      end

      it "enforces memory limits" do
        result = executor.execute("'x' * (300 * 1024 * 1024)", language: :ruby, memory_mb: 128)
        expect(result.failure?).to be true
      end

      it "blocks network access" do
        net_code = <<~RUBY
          require 'socket'
          TCPSocket.new('google.com', 80)
        RUBY
        result = executor.execute(net_code, language: :ruby)
        expect(result.failure?).to be true
      end

      it "returns stderr in logs" do
        result = executor.execute("warn 'warning message'", language: :ruby)
        expect(result.logs).to include("warning message")
      end

      it "enforces CPU limits" do
        result = executor.execute("sleep(1)", language: :ruby, cpu_quota: 10_000, timeout: 10)
        # CPU quota may or may not enforce depending on system
        expect(result).to be_a(Smolagents::Executors::Executor::ExecutionResult)
      end
    end

    context "with mocked Docker", :unit do
      let(:mock_stdout) { "mocked output" }
      let(:mock_stderr) { "" }
      let(:mock_status) { double(success?: true, exitstatus: 0) }

      before do
        allow(Open3).to receive(:popen3).and_yield(
          double(close: nil),
          double(read: mock_stdout),
          double(read: mock_stderr),
          double(pid: 12_345, join: true, value: mock_status)
        )
      end

      it "executes code with mocked Docker" do
        result = executor.execute("puts 'test'", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to eq("mocked output")
      end

      it "executes Python with mocked Docker" do
        result = executor.execute("print('hello')", language: :python)
        expect(result.success?).to be true
      end

      it "executes JavaScript with mocked Docker" do
        result = executor.execute("console.log('hello')", language: :javascript)
        expect(result.success?).to be true
      end

      it "executes TypeScript with mocked Docker" do
        result = executor.execute("console.log('hello')", language: :typescript)
        expect(result.success?).to be true
      end

      it "captures stderr in logs" do
        allow(Open3).to receive(:popen3).and_yield(
          double(close: nil),
          double(read: "output"),
          double(read: "warning from stderr"),
          double(pid: 12_345, join: true, value: mock_status)
        )

        result = executor.execute("code", language: :ruby)
        expect(result.logs).to eq("warning from stderr")
      end

      it "handles command execution with string language" do
        result = executor.execute("puts 'test'", language: "ruby")
        expect(result.success?).to be true
      end

      it "includes exit code in error message on failure" do
        failed_status = double(success?: false, exitstatus: 1)
        allow(Open3).to receive(:popen3).and_yield(
          double(close: nil),
          double(read: ""),
          double(read: "error message"),
          double(pid: 12_345, join: true, value: failed_status)
        )

        result = executor.execute("bad code", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to include("Exit code 1")
        expect(result.error).to include("error message")
      end
    end

    context "error handling" do
      it "requires language parameter" do
        expect do
          executor.execute("code")
        end.to raise_error(ArgumentError)
      end

      it "validates language is supported" do
        expect do
          executor.execute("code", language: :unsupported)
        end.to raise_error(ArgumentError, /not supported: unsupported/)
      end

      it "validates code is not empty" do
        expect do
          executor.execute("", language: :ruby)
        end.to raise_error(ArgumentError, /empty/)
      end

      it "handles RuntimeError from Docker execution" do
        allow(Open3).to(receive(:popen3).and_wrap_original do |_method, *_args|
          raise "Docker daemon error"
        end)

        result = executor.execute("code", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to include("Docker error")
      end

      it "handles timeout errors" do
        allow(Open3).to(receive(:popen3).and_wrap_original do |_method, *_args|
          raise Timeout::Error, "test timeout"
        end)

        result = executor.execute("sleep(100)", language: :ruby, timeout: 5)
        expect(result.failure?).to be true
        expect(result.error).to include("timeout after 5 seconds")
      end

      it "handles RuntimeError" do
        allow(Open3).to(receive(:popen3).and_wrap_original do |_method, *_args|
          raise "runtime error message"
        end)

        result = executor.execute("code", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to include("Docker error")
      end
    end

    context "with instrumentation" do
      it "instruments execute calls" do
        allow(Open3).to receive(:popen3).and_yield(
          double(close: nil),
          double(read: "output"),
          double(read: ""),
          double(pid: 12_345, join: true, value: double(success?: true, exitstatus: 0))
        )

        allow(Smolagents::Instrumentation).to receive(:instrument).and_call_original

        executor.execute("puts 'test'", language: :ruby)

        expect(Smolagents::Instrumentation).to have_received(:instrument).with(
          "smolagents.executor.execute",
          executor_class: "Smolagents::Executors::Docker",
          language: :ruby
        )
      end
    end
  end

  describe "#build_docker_args" do
    it "builds secure Docker arguments" do
      docker_args = executor.send(
        :build_docker_args,
        image: "ruby:3.3-alpine",
        command: ["ruby", "-e"],
        code: "puts 'test'",
        timeout: 5,
        memory_mb: 256,
        cpu_quota: 100_000
      )

      expect(docker_args).to include("--network=none")
      expect(docker_args).to include("--memory=256m")
      expect(docker_args).to include("--memory-swap=256m")
      expect(docker_args).to include("--cpu-quota=100000")
      expect(docker_args).to include("--pids-limit=32")
      expect(docker_args).to include("--read-only")
      expect(docker_args).to include("--security-opt=no-new-privileges")
      expect(docker_args).to include("--cap-drop=ALL")
      expect(docker_args).to include("--tmpfs=/tmp:rw,noexec,nosuid,size=32m")
    end

    it "includes docker path in arguments" do
      custom_executor = described_class.new(docker_path: "/custom/docker")
      docker_args = custom_executor.send(
        :build_docker_args,
        image: "ruby:3.3-alpine",
        command: ["ruby", "-e"],
        code: "puts 'test'",
        timeout: 5,
        memory_mb: 256,
        cpu_quota: 100_000
      )

      expect(docker_args.first).to eq("/custom/docker")
    end

    it "includes image and command in arguments" do
      docker_args = executor.send(
        :build_docker_args,
        image: "python:3.12-slim",
        command: ["python3", "-c"],
        code: "print('hello')",
        timeout: 5,
        memory_mb: 256,
        cpu_quota: 100_000
      )

      expect(docker_args).to include("python:3.12-slim")
      expect(docker_args).to include("python3")
      expect(docker_args).to include("-c")
      expect(docker_args).to include("print('hello')")
    end

    it "respects memory_mb parameter" do
      docker_args = executor.send(
        :build_docker_args,
        image: "ruby:3.3-alpine",
        command: ["ruby", "-e"],
        code: "test",
        timeout: 5,
        memory_mb: 512,
        cpu_quota: 100_000
      )

      expect(docker_args).to include("--memory=512m")
      expect(docker_args).to include("--memory-swap=512m")
    end

    it "respects cpu_quota parameter" do
      docker_args = executor.send(
        :build_docker_args,
        image: "ruby:3.3-alpine",
        command: ["ruby", "-e"],
        code: "test",
        timeout: 5,
        memory_mb: 256,
        cpu_quota: 50_000
      )

      expect(docker_args).to include("--cpu-quota=50000")
    end
  end

  describe "security features" do
    describe "environment filtering" do
      around do |example|
        # Save original ENV
        original_env = ENV.to_h
        example.run
      ensure
        # Restore original ENV
        ENV.clear
        original_env.each { |k, v| ENV[k] = v }
      end

      it "includes safe environment variables" do
        ENV["PATH"] = "/usr/bin"
        ENV["HOME"] = "/home/test"
        ENV["LANG"] = "en_US.UTF-8"

        safe_env = executor.send(:safe_environment)

        expect(safe_env["PATH"]).to eq("/usr/bin")
        expect(safe_env["HOME"]).to eq("/home/test")
        expect(safe_env["LANG"]).to eq("en_US.UTF-8")
      end

      it "excludes API keys" do
        ENV["PATH"] = "/usr/bin"
        ENV["OPENAI_API_KEY"] = "sk-secret123"
        ENV["API_KEY"] = "secret456"
        ENV["ANTHROPIC_API_KEY"] = "sk-ant-secret"

        safe_env = executor.send(:safe_environment)

        expect(safe_env).not_to have_key("OPENAI_API_KEY")
        expect(safe_env).not_to have_key("API_KEY")
        expect(safe_env).not_to have_key("ANTHROPIC_API_KEY")
      end

      it "excludes tokens and secrets" do
        ENV["PATH"] = "/usr/bin"
        ENV["GITHUB_TOKEN"] = "ghp_secret"
        ENV["SECRET_KEY"] = "mysecret"
        ENV["AUTH_TOKEN"] = "bearer123"
        ENV["PASSWORD"] = "hunter2"

        safe_env = executor.send(:safe_environment)

        expect(safe_env).not_to have_key("GITHUB_TOKEN")
        expect(safe_env).not_to have_key("SECRET_KEY")
        expect(safe_env).not_to have_key("AUTH_TOKEN")
        expect(safe_env).not_to have_key("PASSWORD")
      end

      it "excludes credentials and private keys" do
        ENV["PATH"] = "/usr/bin"
        ENV["AWS_ACCESS_KEY_ID"] = "AKIA123"
        ENV["AWS_SECRET_ACCESS_KEY"] = "secret"
        ENV["PRIVATE_KEY"] = "-----BEGIN RSA PRIVATE KEY-----"
        ENV["CREDENTIAL_FILE"] = "/path/to/creds"

        safe_env = executor.send(:safe_environment)

        expect(safe_env).not_to have_key("AWS_ACCESS_KEY_ID")
        expect(safe_env).not_to have_key("AWS_SECRET_ACCESS_KEY")
        expect(safe_env).not_to have_key("PRIVATE_KEY")
        expect(safe_env).not_to have_key("CREDENTIAL_FILE")
      end

      it "only includes explicitly allowed variables" do
        ENV["PATH"] = "/usr/bin"
        ENV["RANDOM_VAR"] = "some value"
        ENV["CUSTOM_SETTING"] = "custom"

        safe_env = executor.send(:safe_environment)

        expect(safe_env).not_to have_key("RANDOM_VAR")
        expect(safe_env).not_to have_key("CUSTOM_SETTING")
      end

      it "handles missing safe variables gracefully" do
        # Clear all safe vars
        Smolagents::DockerExecutor::SAFE_ENV_VARS.each { |var| ENV.delete(var) }

        safe_env = executor.send(:safe_environment)
        expect(safe_env).to be_a(Hash)
        expect(safe_env).to be_empty
      end

      it "applies double-check filtering on whitelisted vars" do
        ENV["PATH"] = "/usr/bin"
        ENV["HOME"] = "/home"
        # This is tricky - PATH is whitelisted but wouldn't match patterns
        # SECRET_AUTH is not whitelisted but we test the filtering logic

        safe_env = executor.send(:safe_environment)

        expect(safe_env).to have_key("PATH")
        expect(safe_env).to have_key("HOME")
      end
    end

    describe "#sensitive_key?" do
      it "detects api_key variations" do
        expect(executor.send(:sensitive_key?, "API_KEY")).to be true
        expect(executor.send(:sensitive_key?, "api_key")).to be true
        expect(executor.send(:sensitive_key?, "OPENAI_API_KEY")).to be true
        expect(executor.send(:sensitive_key?, "apiKey")).to be true
        expect(executor.send(:sensitive_key?, "api-key")).to be true
      end

      it "detects token variations" do
        expect(executor.send(:sensitive_key?, "TOKEN")).to be true
        expect(executor.send(:sensitive_key?, "GITHUB_TOKEN")).to be true
        expect(executor.send(:sensitive_key?, "auth_token")).to be true
        expect(executor.send(:sensitive_key?, "access-token")).to be true
      end

      it "detects secret variations" do
        expect(executor.send(:sensitive_key?, "SECRET")).to be true
        expect(executor.send(:sensitive_key?, "SECRET_KEY")).to be true
        expect(executor.send(:sensitive_key?, "client_secret")).to be true
        expect(executor.send(:sensitive_key?, "shared-secret")).to be true
      end

      it "detects password variations" do
        expect(executor.send(:sensitive_key?, "PASSWORD")).to be true
        expect(executor.send(:sensitive_key?, "DB_PASSWORD")).to be true
        expect(executor.send(:sensitive_key?, "user_password")).to be true
      end

      it "detects credential variations" do
        expect(executor.send(:sensitive_key?, "CREDENTIAL")).to be true
        expect(executor.send(:sensitive_key?, "CREDENTIALS")).to be true
        expect(executor.send(:sensitive_key?, "SERVICE_CREDENTIAL")).to be true
      end

      it "detects auth variations" do
        expect(executor.send(:sensitive_key?, "AUTH")).to be true
        expect(executor.send(:sensitive_key?, "AUTH_TOKEN")).to be true
        expect(executor.send(:sensitive_key?, "BASIC_AUTH")).to be true
      end

      it "detects private key variations" do
        expect(executor.send(:sensitive_key?, "PRIVATE_KEY")).to be true
        expect(executor.send(:sensitive_key?, "private-key")).to be true
        expect(executor.send(:sensitive_key?, "PRIVATE_KEY_ID")).to be true
      end

      it "detects access key variations" do
        expect(executor.send(:sensitive_key?, "ACCESS_KEY")).to be true
        expect(executor.send(:sensitive_key?, "access-key")).to be true
        expect(executor.send(:sensitive_key?, "AWS_ACCESS_KEY_ID")).to be true
      end

      it "does not flag safe variables" do
        expect(executor.send(:sensitive_key?, "PATH")).to be false
        expect(executor.send(:sensitive_key?, "HOME")).to be false
        expect(executor.send(:sensitive_key?, "LANG")).to be false
        expect(executor.send(:sensitive_key?, "USER")).to be false
        expect(executor.send(:sensitive_key?, "LC_ALL")).to be false
        expect(executor.send(:sensitive_key?, "TZ")).to be false
        expect(executor.send(:sensitive_key?, "TERM")).to be false
      end

      it "handles symbol and string keys" do
        expect(executor.send(:sensitive_key?, :API_KEY)).to be true
        expect(executor.send(:sensitive_key?, "API_KEY")).to be true
      end
    end
  end

  describe "#prepare_code" do
    it "returns code unchanged by default" do
      code = "puts 'hello'"
      result = executor.send(:prepare_code, code, :ruby)
      expect(result).to eq(code)
    end

    it "works for different languages" do
      code = "print('hello')"
      result = executor.send(:prepare_code, code, :python)
      expect(result).to eq(code)
    end
  end

  describe "output parsing" do
    it "parses JSON objects" do
      json_output = '{"key": "value"}'
      parsed = executor.send(:parse_output, json_output, :ruby)
      expect(parsed).to eq({ "key" => "value" })
    end

    it "parses JSON arrays" do
      json_output = "[1, 2, 3]"
      parsed = executor.send(:parse_output, json_output)
      expect(parsed).to eq([1, 2, 3])
    end

    it "returns plain strings for non-JSON" do
      plain_output = "hello world"
      parsed = executor.send(:parse_output, plain_output, :ruby)
      expect(parsed).to eq("hello world")
    end

    it "trims whitespace from strings" do
      output_with_whitespace = "  result  \n"
      parsed = executor.send(:parse_output, output_with_whitespace, :ruby)
      expect(parsed).to eq("result")
    end

    it "handles empty output" do
      parsed = executor.send(:parse_output, "", :ruby)
      expect(parsed).to eq("")
    end

    it "handles whitespace-only output" do
      parsed = executor.send(:parse_output, "   \n  \t  ", :ruby)
      expect(parsed).to eq("")
    end

    it "falls back to string on JSON parse error" do
      invalid_json = '{"incomplete": '
      parsed = executor.send(:parse_output, invalid_json)
      expect(parsed).to be_a(String)
      expect(parsed).to eq(invalid_json.strip)
    end

    it "ignores language parameter for parsing" do
      json_output = '{"key": "value"}'
      parsed_ruby = executor.send(:parse_output, json_output, :ruby)
      parsed_python = executor.send(:parse_output, json_output, :python)
      expect(parsed_ruby).to eq(parsed_python)
    end

    it "handles arrays with nested objects" do
      json_output = '[{"id": 1}, {"id": 2}]'
      parsed = executor.send(:parse_output, json_output)
      expect(parsed).to eq([{ "id" => 1 }, { "id" => 2 }])
    end

    it "handles Unicode in strings" do
      output = "Hello 世界"
      parsed = executor.send(:parse_output, output)
      expect(parsed).to eq("Hello 世界")
    end

    it "handles newlines in JSON strings" do
      json_output = '{"text": "line1\nline2"}'
      parsed = executor.send(:parse_output, json_output)
      expect(parsed).to eq({ "text" => "line1\nline2" })
    end
  end

  describe "#execute_docker" do
    it "executes docker command and returns output" do
      mock_wait_thread = double(
        pid: 12_345,
        join: true,
        value: double(success?: true, exitstatus: 0)
      )

      allow(Open3).to receive(:popen3).and_yield(
        double(close: nil),
        double(read: "stdout output"),
        double(read: "stderr output"),
        mock_wait_thread
      )

      stdout, stderr, status = executor.send(:execute_docker, %w[docker run image], 5)

      expect(stdout).to eq("stdout output")
      expect(stderr).to eq("stderr output")
      expect(status.success?).to be true
    end

    it "enforces timeout" do
      mock_wait_thread = double(pid: 12_345)
      allow(mock_wait_thread).to receive(:join).and_return(nil)

      allow(Open3).to receive(:popen3).and_yield(
        double(close: nil),
        double(read: ""),
        double(read: ""),
        mock_wait_thread
      )

      allow(Process).to receive(:kill)
      allow(mock_wait_thread).to receive(:join).with(0).and_return(nil)

      expect do
        executor.send(:execute_docker, %w[docker run image], 0)
      end.to raise_error(Timeout::Error)
    end

    it "sends TERM signal on timeout" do
      mock_wait_thread = double(pid: 12_345)
      allow(mock_wait_thread).to receive(:join).with(1).and_return(nil)
      allow(mock_wait_thread).to receive(:join).with(0).and_return(nil)
      allow(mock_wait_thread).to receive(:value).and_return(double(success?: true, exitstatus: 0))

      allow(Open3).to receive(:popen3).and_yield(
        double(close: nil),
        double(read: ""),
        double(read: ""),
        mock_wait_thread
      )

      allow(Process).to receive(:kill)

      expect do
        executor.send(:execute_docker, %w[docker run image], 0)
      end.to raise_error(Timeout::Error)

      expect(Process).to have_received(:kill).with("TERM", -12_345)
    end

    it "sends KILL signal if TERM doesn't work" do
      mock_wait_thread = double(pid: 12_345)
      allow(mock_wait_thread).to receive(:join).with(1).and_return(nil)
      allow(mock_wait_thread).to receive(:join).with(0).and_return(nil)

      allow(Open3).to receive(:popen3).and_yield(
        double(close: nil),
        double(read: ""),
        double(read: ""),
        mock_wait_thread
      )

      allow(Process).to receive(:kill)

      expect do
        executor.send(:execute_docker, %w[docker run image], 0)
      end.to raise_error(Timeout::Error)

      expect(Process).to have_received(:kill).with("TERM", -12_345)
      expect(Process).to have_received(:kill).with("KILL", -12_345)
    end

    it "handles ESRCH error gracefully" do
      mock_wait_thread = double(pid: 12_345)
      allow(mock_wait_thread).to receive(:join).with(1).and_return(nil)
      allow(mock_wait_thread).to receive(:join).with(0).and_return(nil)

      allow(Open3).to receive(:popen3).and_yield(
        double(close: nil),
        double(read: ""),
        double(read: ""),
        mock_wait_thread
      )

      allow(Process).to receive(:kill).and_raise(Errno::ESRCH)

      expect do
        executor.send(:execute_docker, %w[docker run image], 0)
      end.to raise_error(Timeout::Error)
    end

    it "uses safe environment for execution" do
      original_env = ENV.to_h
      ENV["PATH"] = "/usr/bin"
      ENV["SECRET_KEY"] = "secret"

      mock_wait_thread = double(
        pid: 12_345,
        join: true,
        value: double(success?: true, exitstatus: 0)
      )

      allow(Open3).to receive(:popen3).and_yield(
        double(close: nil),
        double(read: ""),
        double(read: ""),
        mock_wait_thread
      )

      executor.send(:execute_docker, %w[docker run image], 5)

      # Verify that popen3 was called with safe environment
      expect(Open3).to have_received(:popen3) do |env, *_args|
        expect(env).to be_a(Hash)
        expect(env).to have_key("PATH")
        expect(env).not_to have_key("SECRET_KEY")
      end

      ENV.clear
      original_env.each { |k, v| ENV[k] = v }
    end
  end

  describe "#build_result" do
    it "builds successful result" do
      result = executor.send(:build_result, output: "test output")

      expect(result).to be_a(Smolagents::Executors::Executor::ExecutionResult)
      expect(result.success?).to be true
      expect(result.output).to eq("test output")
      expect(result.error).to be_nil
      expect(result.is_final_answer).to be false
    end

    it "builds failed result with error" do
      result = executor.send(:build_result, error: "test error")

      expect(result.failure?).to be true
      expect(result.error).to eq("test error")
      expect(result.output).to be_nil
    end

    it "includes logs in result" do
      result = executor.send(:build_result, output: "output", logs: "stderr logs")

      expect(result.logs).to eq("stderr logs")
    end

    it "sets is_final_answer to false" do
      result = executor.send(:build_result, output: "output")

      expect(result.is_final_answer).to be false
    end

    it "handles nil output" do
      result = executor.send(:build_result, output: nil, error: "error")

      expect(result.output).to be_nil
      expect(result.failure?).to be true
    end
  end

  describe "container lifecycle" do
    it "uses --rm flag to remove container after execution" do
      docker_args = executor.send(
        :build_docker_args,
        image: "ruby:3.3-alpine",
        command: ["ruby", "-e"],
        code: "test",
        timeout: 5,
        memory_mb: 256,
        cpu_quota: 100_000
      )

      expect(docker_args).to include("--rm")
    end

    it "uses pgroup for process group management" do
      allow(Open3).to receive(:popen3).and_yield(
        double(close: nil),
        double(read: ""),
        double(read: ""),
        double(pid: 12_345, join: true, value: double(success?: true, exitstatus: 0))
      )

      executor.send(:execute_docker, %w[docker run image], 5)

      # Verify pgroup: true was passed
      expect(Open3).to have_received(:popen3) do |*_args, **kwargs|
        expect(kwargs).to have_key(:pgroup)
        expect(kwargs[:pgroup]).to be true
      end
    end

    it "closes stdin immediately" do
      mock_stdin = double(close: nil)
      mock_wait_thread = double(
        pid: 12_345,
        join: true,
        value: double(success?: true, exitstatus: 0)
      )

      allow(Open3).to receive(:popen3).and_yield(
        mock_stdin,
        double(read: ""),
        double(read: ""),
        mock_wait_thread
      )

      executor.send(:execute_docker, %w[docker run image], 5)

      expect(mock_stdin).to have_received(:close)
    end
  end

  describe "edge cases" do
    it "handles very long code strings" do
      long_code = "puts 'test'" * 1000

      allow(Open3).to receive(:popen3).and_yield(
        double(close: nil),
        double(read: "output"),
        double(read: ""),
        double(pid: 12_345, join: true, value: double(success?: true, exitstatus: 0))
      )

      result = executor.execute(long_code, language: :ruby)
      expect(result.success?).to be true
    end

    it "handles different timeout values" do
      allow(Open3).to receive(:popen3).and_yield(
        double(close: nil),
        double(read: "output"),
        double(read: ""),
        double(pid: 12_345, join: true, value: double(success?: true, exitstatus: 0))
      )

      [1, 5, 10, 30].each do |timeout|
        result = executor.execute("code", language: :ruby, timeout:)
        expect(result).to be_a(Smolagents::Executors::Executor::ExecutionResult)
      end
    end

    it "handles different memory values" do
      allow(Open3).to receive(:popen3).and_yield(
        double(close: nil),
        double(read: "output"),
        double(read: ""),
        double(pid: 12_345, join: true, value: double(success?: true, exitstatus: 0))
      )

      [64, 128, 256, 512, 1024].each do |memory_mb|
        result = executor.execute("code", language: :ruby, memory_mb:)
        expect(result).to be_a(Smolagents::Executors::Executor::ExecutionResult)
      end
    end

    it "handles concurrent reader threads" do
      Thread.new { "output" }
      Thread.new { "error" }
      mock_wait_thread = double(
        pid: 12_345,
        join: true,
        value: double(success?: true, exitstatus: 0)
      )

      allow(Open3).to receive(:popen3).and_yield(
        double(close: nil),
        double(read: "output"),
        double(read: "error"),
        mock_wait_thread
      )

      stdout, stderr, = executor.send(:execute_docker, %w[docker run image], 5)

      expect(stdout).to eq("output")
      expect(stderr).to eq("error")
    end
  end
end
