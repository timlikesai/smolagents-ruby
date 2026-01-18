require "smolagents"
require "webmock/rspec"

RSpec.describe Smolagents::Discovery::Scanner do
  describe ".scan_local_servers" do
    before do
      # Stub all default server ports to avoid connection attempts
      Smolagents::Discovery::LOCAL_SERVERS.each_value do |config|
        config[:ports].each do |port|
          stub_request(:get, %r{http://localhost:#{port}/})
            .to_return(status: 404)
        end
      end
    end

    it "scans default servers" do
      stub_request(:get, "http://localhost:1234/api/v1/models")
        .to_return(status: 200, body: '{"models": []}')

      servers = described_class.scan_local_servers(timeout: 0.5, custom_endpoints: [])

      # Should have scanned default servers
      expect(servers).to be_an(Array)
    end

    it "includes custom endpoints in scan" do
      custom = [{ provider: :openai_compatible, host: "custom.local", port: 8080 }]

      stub_request(:get, %r{http://custom.local:8080/})
        .to_return(status: 404)

      servers = described_class.scan_local_servers(timeout: 0.5, custom_endpoints: custom)

      custom_server = servers.find { |s| s.host == "custom.local" }
      expect(custom_server).not_to be_nil
    end
  end

  describe ".scan_cloud_providers" do
    around do |example|
      original_keys = {}
      Smolagents::Discovery::CLOUD_PROVIDERS.each_value do |config|
        original_keys[config[:env_var]] = ENV.fetch(config[:env_var], nil)
        ENV.delete(config[:env_var])
      end

      example.run
    ensure
      original_keys.each do |key, value|
        if value
          ENV[key] = value
        else
          ENV.delete(key)
        end
      end
    end

    it "returns all cloud providers" do
      providers = described_class.scan_cloud_providers

      expect(providers.length).to eq(Smolagents::Discovery::CLOUD_PROVIDERS.length)
    end

    it "marks provider as configured when env var is set" do
      ENV["OPENAI_API_KEY"] = "sk-test"

      providers = described_class.scan_cloud_providers
      openai = providers.find { |p| p.provider == :openai }

      expect(openai.configured?).to be true
    end

    it "marks provider as not configured when env var is empty" do
      ENV["OPENAI_API_KEY"] = ""

      providers = described_class.scan_cloud_providers
      openai = providers.find { |p| p.provider == :openai }

      expect(openai.configured?).to be false
    end

    it "marks provider as not configured when env var is unset" do
      providers = described_class.scan_cloud_providers
      openai = providers.find { |p| p.provider == :openai }

      expect(openai.configured?).to be false
    end

    it "includes env_var in result" do
      providers = described_class.scan_cloud_providers
      openai = providers.find { |p| p.provider == :openai }

      expect(openai.env_var).to eq("OPENAI_API_KEY")
    end
  end

  describe ".scan_default_servers" do
    before do
      Smolagents::Discovery::LOCAL_SERVERS.each_value do |config|
        config[:ports].each do |port|
          stub_request(:get, %r{http://localhost:#{port}/})
            .to_return(status: 404)
        end
      end
    end

    it "scans all configured default servers" do
      servers = described_class.scan_default_servers(0.5)

      # Should return LocalServer for each configured port
      expect(servers).to be_an(Array)
      expect(servers.all?(Smolagents::Discovery::LocalServer)).to be true
    end

    it "sets provider and host correctly" do
      stub_request(:get, "http://localhost:1234/api/v1/models")
        .to_return(status: 200, body: '{"models": []}')

      servers = described_class.scan_default_servers(0.5)
      lm_studio = servers.find { |s| s.provider == :lm_studio }

      expect(lm_studio).not_to be_nil
      expect(lm_studio.host).to eq("localhost")
      expect(lm_studio.port).to eq(1234)
    end
  end

  describe ".scan_custom_endpoints" do
    it "scans custom endpoint with TLS" do
      endpoint = { provider: :openai_compatible, host: "api.example.com", port: 443, tls: true, api_key: "key" }

      stub_request(:get, "https://api.example.com:443/v1/models")
        .with(headers: { "Authorization" => "Bearer key" })
        .to_return(status: 200, body: '{"data": [{"id": "model"}]}')

      servers = described_class.scan_custom_endpoints([endpoint], 0.5)

      expect(servers.length).to eq(1)
      expect(servers.first.host).to eq("api.example.com")
    end

    it "uses openai_compatible for unknown providers" do
      endpoint = { provider: nil, host: "unknown.local", port: 9999 }

      stub_request(:get, %r{http://unknown.local:9999/})
        .to_return(status: 404)

      servers = described_class.scan_custom_endpoints([endpoint], 0.5)

      # Should not raise and should attempt scan
      expect(servers).to be_an(Array)
    end
  end

  describe ".scan_server" do
    it "returns LocalServer with models on success" do
      config = Smolagents::Discovery::LOCAL_SERVERS[:lm_studio]

      stub_request(:get, "http://localhost:1234/api/v1/models")
        .to_return(status: 200, body: JSON.generate({
                                                      "models" => [{ "key" => "llama", "loaded_instances" => [] }]
                                                    }))

      server = described_class.scan_server(:lm_studio, "localhost", 1234, config, 0.5)

      expect(server).to be_a(Smolagents::Discovery::LocalServer)
      expect(server.models.length).to eq(1)
      expect(server.error).to be_nil
    end

    it "returns LocalServer with empty models when server unreachable" do
      config = Smolagents::Discovery::LOCAL_SERVERS[:lm_studio]

      stub_request(:get, %r{http://localhost:1234/})
        .to_return(status: 404)

      server = described_class.scan_server(:lm_studio, "localhost", 1234, config, 0.5)

      expect(server.models).to eq([])
    end

    it "handles TLS parameter" do
      config = Smolagents::Discovery::LOCAL_SERVERS[:openai_compatible]

      stub_request(:get, "https://secure.local:443/v1/models")
        .to_return(status: 200, body: '{"data": []}')

      server = described_class.scan_server(:openai_compatible, "secure.local", 443, config, 0.5, tls: true)

      expect(server).to be_a(Smolagents::Discovery::LocalServer)
    end

    it "handles API key parameter" do
      config = Smolagents::Discovery::LOCAL_SERVERS[:openai_compatible]

      stub_request(:get, "http://localhost:8080/v1/models")
        .with(headers: { "Authorization" => "Bearer test-key" })
        .to_return(status: 200, body: '{"data": []}')

      described_class.scan_server(:openai_compatible, "localhost", 8080, config, 0.5, api_key: "test-key")

      expect(WebMock).to have_requested(:get, "http://localhost:8080/v1/models")
        .with(headers: { "Authorization" => "Bearer test-key" })
    end
  end

  describe ".build_server_result" do
    let(:ctx) do
      Smolagents::Discovery::ScanContext.new(
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        timeout: 0.5,
        tls: false,
        api_key: nil
      )
    end

    let(:config) { Smolagents::Discovery::LOCAL_SERVERS[:lm_studio] }

    it "returns LocalServer with models" do
      models_response = {
        "models" => [{ "key" => "llama", "loaded_instances" => [{ "id" => "llama" }] }]
      }
      stub_request(:get, "http://localhost:1234/api/v1/models")
        .to_return(status: 200, body: JSON.generate(models_response))

      server = described_class.build_server_result(ctx, config)

      expect(server.models.length).to eq(1)
      expect(server.error).to be_nil
    end

    it "captures error message on exception" do
      stub_request(:get, %r{http://localhost:1234/})
        .to_raise(StandardError.new("Connection failed"))

      server = described_class.build_server_result(ctx, config)

      expect(server.models).to eq([])
      expect(server.error).to eq("Connection failed")
    end
  end

  describe ".fetch_models" do
    let(:ctx) do
      Smolagents::Discovery::ScanContext.new(
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        timeout: 0.5,
        tls: false,
        api_key: nil
      )
    end

    let(:config) { Smolagents::Discovery::LOCAL_SERVERS[:lm_studio] }

    it "tries api_v1_path first" do
      stub_request(:get, "http://localhost:1234/api/v1/models")
        .to_return(status: 200, body: JSON.generate({
                                                      "models" => [{ "key" => "model", "loaded_instances" => [] }]
                                                    }))

      models = described_class.fetch_models(ctx, config)

      expect(models.length).to eq(1)
    end

    it "falls back to v0_path" do
      stub_request(:get, "http://localhost:1234/api/v1/models")
        .to_return(status: 404)
      stub_request(:get, "http://localhost:1234/api/v0/models")
        .to_return(status: 200, body: JSON.generate({
                                                      "data" => [{ "id" => "model" }]
                                                    }))

      models = described_class.fetch_models(ctx, config)

      expect(models.length).to eq(1)
    end

    it "falls back to v1_path" do
      stub_request(:get, "http://localhost:1234/api/v1/models")
        .to_return(status: 404)
      stub_request(:get, "http://localhost:1234/api/v0/models")
        .to_return(status: 404)
      stub_request(:get, "http://localhost:1234/v1/models")
        .to_return(status: 200, body: JSON.generate({
                                                      "data" => [{ "id" => "model" }]
                                                    }))

      models = described_class.fetch_models(ctx, config)

      expect(models.length).to eq(1)
    end

    it "returns empty array when all paths fail" do
      stub_request(:get, %r{http://localhost:1234/})
        .to_return(status: 404)

      models = described_class.fetch_models(ctx, config)

      expect(models).to eq([])
    end
  end

  describe ".try_fetch" do
    let(:ctx) do
      Smolagents::Discovery::ScanContext.new(
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        timeout: 0.5,
        tls: false,
        api_key: nil
      )
    end

    let(:config) { { v1_path: "/v1/models" } }

    it "returns models on success" do
      stub_request(:get, "http://localhost:1234/v1/models")
        .to_return(status: 200, body: JSON.generate({
                                                      "data" => [{ "id" => "model" }]
                                                    }))

      models = described_class.try_fetch(ctx, config, :v1_path, :parse_v1_response)

      expect(models.length).to eq(1)
    end

    it "returns nil when path not in config" do
      result = described_class.try_fetch(ctx, {}, :v1_path, :parse_v1_response)

      expect(result).to be_nil
    end

    it "returns nil when request fails" do
      stub_request(:get, "http://localhost:1234/v1/models")
        .to_return(status: 404)

      result = described_class.try_fetch(ctx, config, :v1_path, :parse_v1_response)

      expect(result).to be_nil
    end

    it "returns nil when response has no models" do
      stub_request(:get, "http://localhost:1234/v1/models")
        .to_return(status: 200, body: '{"data": []}')

      result = described_class.try_fetch(ctx, config, :v1_path, :parse_v1_response)

      expect(result).to be_nil
    end
  end

  describe "parallel scanning" do
    before do
      Smolagents::Discovery::LOCAL_SERVERS.each_value do |config|
        config[:ports].each do |port|
          stub_request(:get, %r{http://localhost:#{port}/})
            .to_return(status: 404)
        end
      end
    end

    it "scans multiple servers in parallel" do
      # Stub two servers with artificial delays
      stub_request(:get, "http://localhost:1234/api/v1/models")
        .to_return(status: 200, body: '{"models": []}')
      stub_request(:get, "http://localhost:11434/api/tags")
        .to_return(status: 200, body: '{"models": []}')

      # With sequential scanning, 4 servers * 0.5s timeout = 2s worst case
      # With parallel scanning, all 4 complete in ~0.5s
      start = Time.now
      servers = described_class.scan_default_servers(0.5)
      elapsed = Time.now - start

      expect(servers.length).to be >= 4
      expect(elapsed).to be < 1.5 # Should complete much faster than sequential
    end

    it "handles thread errors gracefully" do
      # Force an error in one thread
      stub_request(:get, "http://localhost:1234/api/v1/models")
        .to_raise(StandardError.new("Thread error"))
      stub_request(:get, "http://localhost:11434/api/tags")
        .to_return(status: 200, body: '{"models": []}')

      servers = described_class.scan_default_servers(0.5)

      # Should still return results for all servers
      expect(servers).to be_an(Array)
      lm_studio = servers.find { |s| s.provider == :lm_studio }
      expect(lm_studio.error).to eq("Thread error")
    end

    it "completes all scans even when some fail" do
      # Stub servers - one returns 500, others succeed/404
      stub_request(:get, "http://localhost:1234/api/v1/models")
        .to_return(status: 500, body: "Internal Server Error")

      servers = described_class.scan_default_servers(0.5)

      # Should still return results for all servers
      expect(servers.length).to be >= 4
      # All servers should be scanned, even if no models found
      providers = servers.map(&:provider)
      expect(providers).to include(:lm_studio, :ollama)
    end
  end

  describe ".scan_in_parallel" do
    it "returns empty array for empty tasks" do
      result = described_class.scan_in_parallel([], 1.0)
      expect(result).to eq([])
    end

    it "collects results from all threads" do
      tasks = [
        { provider: :test1, host: "localhost", port: 1111, config: {}, timeout: 0.1 },
        { provider: :test2, host: "localhost", port: 2222, config: {}, timeout: 0.1 }
      ]

      stub_request(:get, %r{http://localhost:1111/}).to_return(status: 404)
      stub_request(:get, %r{http://localhost:2222/}).to_return(status: 404)

      results = described_class.scan_in_parallel(tasks, 0.5)

      expect(results.length).to eq(2)
      expect(results.map(&:provider)).to contain_exactly(:test1, :test2)
    end
  end

  describe ".build_default_scan_tasks" do
    it "creates a task for each server/port combination" do
      tasks = described_class.build_default_scan_tasks(1.0)

      expect(tasks).to be_an(Array)
      expect(tasks.all?(Hash)).to be true
      expect(tasks.first).to include(:provider, :host, :port, :config, :timeout)
    end
  end

  describe ".build_custom_scan_tasks" do
    it "creates tasks from custom endpoints" do
      endpoints = [
        { provider: :ollama, host: "server1", port: 11_434 },
        { provider: nil, host: "server2", port: 8080, tls: true, api_key: "key" }
      ]

      tasks = described_class.build_custom_scan_tasks(endpoints, 2.0)

      expect(tasks.length).to eq(2)
      expect(tasks[0][:provider]).to eq(:ollama)
      expect(tasks[1][:tls]).to be true
      expect(tasks[1][:api_key]).to eq("key")
    end
  end
end
