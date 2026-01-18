require "json"
require_relative "scan_context"
require_relative "response_parsers"

module Smolagents
  module Discovery
    # Scans local servers for available models using parallel threads.
    module Scanner
      module_function

      def scan_local_servers(timeout:, custom_endpoints:)
        default_tasks = build_default_scan_tasks(timeout)
        custom_tasks = build_custom_scan_tasks(custom_endpoints, timeout)
        scan_in_parallel(default_tasks + custom_tasks, timeout)
      end

      def scan_cloud_providers
        CLOUD_PROVIDERS.map do |provider, config|
          CloudProvider.new(
            provider:,
            configured: ENV[config[:env_var]].to_s.length.positive?,
            env_var: config[:env_var]
          )
        end
      end

      def scan_default_servers(timeout)
        scan_in_parallel(build_default_scan_tasks(timeout), timeout)
      end

      def scan_custom_endpoints(endpoints, timeout)
        scan_in_parallel(build_custom_scan_tasks(endpoints, timeout), timeout)
      end

      def build_default_scan_tasks(timeout)
        LOCAL_SERVERS.flat_map do |provider, config|
          config[:ports].map { |port| { provider:, host: "localhost", port:, config:, timeout: } }
        end
      end

      def build_custom_scan_tasks(endpoints, timeout)
        endpoints.map do |ep|
          provider = ep[:provider]&.to_sym
          config = LOCAL_SERVERS[provider] || LOCAL_SERVERS[:openai_compatible]
          { provider:, host: ep[:host], port: ep[:port], config:, timeout:, tls: ep[:tls], api_key: ep[:api_key] }
        end
      end

      def scan_in_parallel(tasks, timeout)
        return [] if tasks.empty?

        threads = tasks.map { |task| Thread.new { scan_task(task) } }
        collect_results(threads, timeout)
      end

      def collect_results(threads, timeout)
        deadline = Time.now + timeout + 0.5
        threads.filter_map { |t| t.join([deadline - Time.now, 0.1].max)&.value }
      end

      def scan_task(task)
        scan_server(task[:provider], task[:host], task[:port], task[:config], task[:timeout],
                    tls: task[:tls], api_key: task[:api_key])
      end

      def scan_server(provider, host, port, config, timeout, tls: false, api_key: nil)
        ctx = ScanContext.new(provider:, host:, port:, timeout:, tls:, api_key:)
        build_server_result(ctx, config)
      end

      def build_server_result(ctx, config)
        models = fetch_models(ctx, config)
        LocalServer.new(provider: ctx.provider, host: ctx.host, port: ctx.port, models:, error: nil)
      rescue StandardError => e
        LocalServer.new(provider: ctx.provider, host: ctx.host, port: ctx.port, models: [], error: e.message)
      end

      def fetch_models(ctx, config)
        try_fetch(ctx, config, :api_v1_path, :parse_lm_studio_response) ||
          try_fetch(ctx, config, :v0_path, :parse_v0_response) ||
          try_fetch(ctx, config, :v1_path, :parse_v1_response) ||
          try_fetch(ctx, config, :api_path, :parse_native_response) ||
          []
      end

      def try_fetch(ctx, config, path_key, parser)
        path = config[path_key]
        return nil unless path

        response = HttpClient.get(host: ctx.host, port: ctx.port, path:,
                                  timeout: ctx.timeout, tls: ctx.tls, api_key: ctx.api_key)
        return nil unless response

        models = ResponseParsers.send(parser, response, ctx)
        models.any? ? models : nil
      end
    end
  end
end
