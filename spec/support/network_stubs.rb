# Network Stubs for Unit Testing
#
# Unit tests must NEVER make real network calls. This module provides
# stubs for all network-related operations to ensure tests are:
#
# 1. Fast (no 25-30ms DNS lookups, no HTTP latency)
# 2. Deterministic (no flaky failures from network issues)
# 3. Isolated (no external dependencies)
#
# For integration tests that need real network access, use the :integration
# tag which skips these stubs and uses live services.
#
# Usage Patterns:
#
#   # WebMock stubs HTTP requests
#   stub_request(:get, "https://api.example.com/data")
#     .to_return(status: 200, body: '{"result": "ok"}')
#
#   # DNS is automatically stubbed - no action needed
#   # All hostnames resolve to 93.184.216.34 (example.com's real IP)
#
#   # To test specific DNS behavior or port availability:
#   stub_dns("custom.example.com", "1.2.3.4")
#   stub_port_open("localhost", 1234)  # Simulate server running
#
module NetworkStubs
  # Fake public IP that passes SSRF checks (example.com's real IP)
  STUB_PUBLIC_IP = "93.184.216.34".freeze

  @dns_map = {}
  @open_ports = Set.new

  class << self
    attr_accessor :dns_map, :open_ports

    def reset!
      @dns_map = {}
      @open_ports = Set.new
    end

    def stub_dns(hostname, ip)
      @dns_map[hostname] = ip
    end

    def resolve(hostname)
      @dns_map[hostname] || STUB_PUBLIC_IP
    end

    def stub_port_open(host, port)
      @open_ports.add("#{host}:#{port}")
    end

    def port_open?(host, port)
      @open_ports.include?("#{host}:#{port}")
    end
  end
end

# Override Resolv methods for instant DNS resolution in tests
class Resolv
  class << self
    def getaddress(hostname)
      NetworkStubs.resolve(hostname)
    end

    def getaddresses(hostname)
      [NetworkStubs.resolve(hostname)]
    end
  end
end

# Stub Socket.tcp for port availability checks
# By default, all ports are closed unless explicitly stubbed open
class Socket
  class << self
    alias real_tcp tcp

    def tcp(host, port, connect_timeout: nil, **) # rubocop:disable Lint/UnusedMethodArgument
      raise Errno::ECONNREFUSED unless NetworkStubs.port_open?(host, port)

      # Return a mock socket that responds to close
      Object.new.tap { |s| s.define_singleton_method(:close) { nil } }
    end
  end
end

RSpec.configure do |config|
  config.before do
    NetworkStubs.reset!
  end
end
