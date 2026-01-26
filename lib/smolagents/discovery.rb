require_relative "discovery/config"
require_relative "discovery/types"
require_relative "discovery/http_client"
require_relative "discovery/url_parser"
require_relative "discovery/scan_context"
require_relative "discovery/model_builder"
require_relative "discovery/response_parsers"
require_relative "discovery/scanner"

module Smolagents
  # Load .env file if present (simple dotenv-like behavior).
  def self.load_dotenv
    return if test_environment?

    env_file = File.join(Dir.pwd, ".env")
    return unless File.exist?(env_file)

    File.readlines(env_file).each { |line| parse_env_line(line) }
  end

  def self.test_environment?
    defined?(RSpec) || defined?(Minitest) || ENV["RAILS_ENV"] == "test" || ENV["RACK_ENV"] == "test"
  end

  def self.parse_env_line(line)
    line = line.strip
    return if line.empty? || line.start_with?("#")

    key, value = line.split("=", 2)
    return unless key && value

    ENV[key.strip] ||= strip_quotes(value.strip)
  end

  def self.strip_quotes(value)
    return value[1..-2] if (value.start_with?('"') && value.end_with?('"')) ||
                           (value.start_with?("'") && value.end_with?("'"))

    value
  end

  load_dotenv

  # Auto-discovery of local inference servers and cloud API credentials.
  module Discovery
    class << self
      # Performs a full discovery scan.
      def scan(timeout: 2.0, custom_endpoints: [])
        all_endpoints = UrlParser.parse_endpoints_env + custom_endpoints
        local_servers = Scanner.scan_local_servers(timeout:, custom_endpoints: all_endpoints)
        cloud_providers = Scanner.scan_cloud_providers

        Result.new(local_servers:, cloud_providers:, scanned_at: Time.now)
      end

      # Quick check if any models are available without full scan.
      def available?
        cloud_available? || local_available?
      end

      private

      def cloud_available?
        CLOUD_PROVIDERS.any? { |_, cfg| ENV.fetch(cfg[:env_var], nil) }
      end

      def local_available?
        LOCAL_SERVERS.any? do |_, cfg|
          cfg[:ports].any? { |port| HttpClient.port_open?("localhost", port, timeout: 0.5) }
        end
      end
    end
  end
end
