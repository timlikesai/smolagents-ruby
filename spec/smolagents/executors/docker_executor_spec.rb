# frozen_string_literal: true

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
  end

  describe "DEFAULT_IMAGES" do
    it "defines default images for all supported languages" do
      expect(described_class::DEFAULT_IMAGES[:ruby]).to eq("ruby:3.3-alpine")
      expect(described_class::DEFAULT_IMAGES[:python]).to eq("python:3.12-slim")
      expect(described_class::DEFAULT_IMAGES[:javascript]).to eq("node:20-alpine")
      expect(described_class::DEFAULT_IMAGES[:typescript]).to eq("node:20-alpine")
    end
  end

  describe "COMMANDS" do
    it "defines commands for all supported languages" do
      expect(described_class::COMMANDS[:ruby]).to eq(["ruby", "-e"])
      expect(described_class::COMMANDS[:python]).to eq(["python3", "-c"])
      expect(described_class::COMMANDS[:javascript]).to eq(["node", "-e"])
      expect(described_class::COMMANDS[:typescript]).to eq(["npx", "-y", "tsx", "-e"])
    end
  end

  describe "#initialize" do
    it "accepts custom images" do
      executor = described_class.new(images: { ruby: "ruby:3.2-slim" })
      expect(executor.instance_variable_get(:@images)[:ruby]).to eq("ruby:3.2-slim")
    end

    it "merges custom images with defaults" do
      executor = described_class.new(images: { ruby: "custom:latest" })
      images = executor.instance_variable_get(:@images)
      expect(images[:ruby]).to eq("custom:latest")
      expect(images[:python]).to eq("python:3.12-slim") # Default still present
    end

    it "accepts custom docker path" do
      executor = described_class.new(docker_path: "/usr/local/bin/docker")
      expect(executor.instance_variable_get(:@docker_path)).to eq("/usr/local/bin/docker")
    end
  end

  describe "#execute" do
    context "with Docker available", :integration do
      before do
        # Check if Docker is available
        skip "Docker not available" unless system("docker --version > /dev/null 2>&1")
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

      it "enforces timeout" do
        result = executor.execute("sleep 10", language: :ruby, timeout: 1)
        expect(result.failure?).to be true
        expect(result.error).to include("timeout")
      end

      it "enforces memory limits" do
        # Try to allocate more memory than limit
        result = executor.execute("'x' * (300 * 1024 * 1024)", language: :ruby, memory_mb: 128)
        expect(result.failure?).to be true
      end

      it "blocks network access" do
        # This should fail because network is disabled
        net_code = <<~RUBY
          require 'socket'
          TCPSocket.new('google.com', 80)
        RUBY
        result = executor.execute(net_code, language: :ruby, timeout: 2)
        expect(result.failure?).to be true
      end

      it "returns stderr in logs" do
        result = executor.execute("warn 'warning message'", language: :ruby)
        expect(result.logs).to include("warning message")
      end
    end

    context "without Docker", :unit do
      it "requires language parameter" do
        expect {
          executor.execute("code")
        }.to raise_error(ArgumentError)
      end

      it "validates language is supported" do
        expect {
          executor.execute("code", language: :unsupported)
        }.to raise_error(ArgumentError, /not supported: unsupported/)
      end
    end
  end

  describe "security features" do
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
    end
  end

  describe "output parsing" do
    it "parses JSON output" do
      json_output = '{"key": "value"}'
      parsed = executor.send(:parse_output, json_output, :ruby)
      expect(parsed).to eq({ "key" => "value" })
    end

    it "returns plain strings for non-JSON" do
      plain_output = "hello world"
      parsed = executor.send(:parse_output, plain_output, :ruby)
      expect(parsed).to eq("hello world")
    end

    it "trims whitespace" do
      output_with_whitespace = "  result  \n"
      parsed = executor.send(:parse_output, output_with_whitespace, :ruby)
      expect(parsed).to eq("result")
    end
  end
end
