module Smolagents
  module Discovery
    # Result of a discovery scan.
    Result = Data.define(:local_servers, :cloud_providers, :scanned_at) do
      def any? = local_servers.any?(&:available?) || cloud_providers.any?(&:configured?)

      def all_models = local_servers.flat_map(&:models)

      def code_examples
        local_examples + cloud_examples
      end

      def summary
        parts = build_summary_parts
        parts.empty? ? "No models discovered" : parts.join(", ")
      end

      private

      def local_examples
        local_servers.select(&:available?).flat_map do |server|
          server.models.select(&:ready?).first(2).map(&:code_example)
        end
      end

      def cloud_examples
        cloud_providers.select(&:configured?).first(2).map(&:code_example)
      end

      def build_summary_parts
        [local_summary, cloud_summary].compact
      end

      def local_summary
        count = local_servers.sum { |s| s.models.count(&:ready?) }
        count.positive? ? pluralize(count, "local model") : nil
      end

      def cloud_summary
        count = cloud_providers.count(&:configured?)
        count.positive? ? pluralize(count, "cloud provider") : nil
      end

      def pluralize(count, singular)
        "#{count} #{singular}#{"s" if count != 1}"
      end
    end

    # A discovered local inference server.
    LocalServer = Data.define(:provider, :host, :port, :models, :error) do
      def available? = models.any?
      def name = LOCAL_SERVERS.dig(provider, :name) || provider.to_s
      def docs = LOCAL_SERVERS.dig(provider, :docs)
      def base_url = "http://#{host}:#{port}"
    end

    # A discovered model from a local server.
    DiscoveredModel = Data.define(:id, :provider, :host, :port, :context_length, :state,
                                  :capabilities, :type, :tls, :api_key) do
      def ready? = %i[loaded available].include?(state)
      def tool_use? = capabilities&.include?("tool_use")
      def vision? = type == "vlm" || capabilities&.include?("vision")
      def base_url = "#{tls ? "https" : "http"}://#{host}:#{port}"
      def localhost? = %w[localhost 127.0.0.1 ::1].include?(host.downcase)

      def code_example
        localhost? && factory_method? ? factory_code_example : explicit_code_example
      end

      private

      def factory_method? = %i[lm_studio ollama llama_cpp vllm mlx_lm].include?(provider)

      def factory_code_example
        suffix = build_code_suffix
        "model = Smolagents::OpenAIModel.#{provider}(\"#{id}\")#{suffix}"
      end

      def explicit_code_example
        key_arg = api_key ? ", api_key: \"#{api_key}\"" : ""
        suffix = build_code_suffix
        "model = Smolagents::OpenAIModel.new(model_id: \"#{id}\", api_base: \"#{base_url}/v1\"#{key_arg})#{suffix}"
      end

      def build_code_suffix
        ctx = context_length ? "  # #{context_length.to_i / 1000}K context" : ""
        state_note = ready? ? "" : " (not loaded)"
        "#{ctx}#{state_note}"
      end
    end

    # Cloud provider configuration status.
    CloudProvider = Data.define(:provider, :configured, :env_var) do
      def configured? = configured
      def name = CLOUD_PROVIDERS.dig(provider, :name) || provider.to_s
      def docs = CLOUD_PROVIDERS.dig(provider, :docs)
      def code_example = CLOUD_CODE_EXAMPLES[provider]
    end
  end
end
