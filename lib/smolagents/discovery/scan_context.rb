module Smolagents
  module Discovery
    # Context object for model scanning to reduce parameter passing.
    ScanContext = Data.define(:provider, :host, :port, :timeout, :tls, :api_key) do
      def base_url = "#{tls ? "https" : "http"}://#{host}:#{port}"

      def with_defaults(tls: false, api_key: nil)
        self.class.new(provider:, host:, port:, timeout:, tls:, api_key:)
      end
    end
  end
end
