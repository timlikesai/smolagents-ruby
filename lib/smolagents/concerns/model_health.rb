module Smolagents
  module Concerns
    # Adds health checking and model discovery capabilities to model classes.
    #
    # This concern provides methods to check if a model server is healthy,
    # query available models, and detect when the loaded model changes.
    #
    # @example Basic health check
    #   model = OpenAIModel.lm_studio("local-model")
    #   if model.healthy?
    #     result = model.generate(messages)
    #   else
    #     puts "Model server unavailable"
    #   end
    #
    # @example Detailed health information
    #   health = model.health_check
    #   case health.status
    #   when :healthy
    #     puts "Server responding in #{health.latency_ms}ms"
    #   when :degraded
    #     puts "Slow response: #{health.latency_ms}ms"
    #   when :unhealthy
    #     puts "Server error: #{health.error}"
    #   end
    #
    # @example Model discovery
    #   models = model.available_models
    #   models.each { |m| puts "#{m.id}: #{m.owned_by}" }
    #
    #   loaded = model.loaded_model
    #   puts "Currently loaded: #{loaded&.id || 'unknown'}"
    #
    # @example Model change detection
    #   model.on_model_change do |old_model, new_model|
    #     logger.info "Model changed: #{old_model} -> #{new_model}"
    #   end
    #
    module ModelHealth # rubocop:disable Metrics/ModuleLength
      # Health check result with status, latency, and optional error
      HealthStatus = Data.define(:status, :latency_ms, :error, :checked_at, :model_id, :details) do
        def healthy? = status == :healthy
        def degraded? = status == :degraded
        def unhealthy? = status == :unhealthy

        def to_h
          { status:, latency_ms:, error:, checked_at: checked_at.iso8601, model_id:, details: }
        end
      end

      # Model information from /v1/models endpoint
      ModelInfo = Data.define(:id, :object, :created, :owned_by, :loaded) do
        def to_h = { id:, object:, created:, owned_by:, loaded: }
      end

      # Default thresholds for health status determination
      HEALTH_THRESHOLDS = {
        healthy_latency_ms: 1000,      # Under 1s = healthy
        degraded_latency_ms: 5000,     # 1-5s = degraded
        timeout_ms: 10_000             # Over 10s = timeout
      }.freeze

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Configure health check thresholds at class level
        #
        # @example
        #   class FastModel < OpenAIModel
        #     health_thresholds healthy_latency_ms: 500, degraded_latency_ms: 2000
        #   end
        def health_thresholds(**thresholds)
          @health_thresholds = HEALTH_THRESHOLDS.merge(thresholds)
        end

        def get_health_thresholds
          @health_thresholds || HEALTH_THRESHOLDS
        end
      end

      # Check if the model server is responding
      #
      # @param cache_for [Integer, nil] Cache result for this many seconds (nil = no cache)
      # @return [Boolean] true if server is healthy or degraded, false if unhealthy
      def healthy?(cache_for: nil)
        check = health_check(cache_for:)
        check.healthy? || check.degraded?
      end

      # Perform a detailed health check
      #
      # @param cache_for [Integer, nil] Cache result for this many seconds
      # @return [HealthStatus] Detailed health status
      def health_check(cache_for: nil)
        if cache_for && @last_health_check
          age = Time.now - @last_health_check.checked_at
          return @last_health_check if age < cache_for
        end

        @last_health_check = perform_health_check
      end

      # Query available models from the server
      #
      # @return [Array<ModelInfo>] List of available models
      # @raise [AgentError] If the models endpoint is not available
      def available_models
        response = models_request
        parse_models_response(response)
      rescue StandardError => e
        raise AgentError, "Failed to query models: #{e.message}"
      end

      # Get information about the currently loaded model (if detectable)
      #
      # For servers that track loaded state (like llama.cpp), returns the
      # currently loaded model. For others, returns the configured model_id.
      #
      # @return [ModelInfo, nil] The loaded model info, or nil if unknown
      def loaded_model
        models = available_models
        # Try to find a model marked as loaded, or fall back to matching model_id
        models.find(&:loaded) || models.find { |m| m.id == model_id }
      rescue AgentError
        nil
      end

      # Register a callback for model change detection
      #
      # @yield [old_model_id, new_model_id] Called when loaded model changes
      def on_model_change(&block)
        @model_change_callbacks ||= []
        @model_change_callbacks << block
      end

      # Check if the loaded model has changed since last check
      #
      # @return [Boolean] true if model changed
      def model_changed?
        current = loaded_model&.id
        changed = @last_known_model && current && current != @last_known_model

        if changed
          old_model = @last_known_model
          @model_change_callbacks&.each { |cb| cb.call(old_model, current) }
        end

        @last_known_model = current
        changed
      end

      # Clear the health check cache
      def clear_health_cache
        @last_health_check = nil
      end

      private

      def perform_health_check # rubocop:disable Metrics/MethodLength
        thresholds = self.class.respond_to?(:get_health_thresholds) ? self.class.get_health_thresholds : HEALTH_THRESHOLDS
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          response = models_request(timeout: thresholds[:timeout_ms] / 1000.0)
          latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

          status = if latency_ms < thresholds[:healthy_latency_ms]
                     :healthy
                   elsif latency_ms < thresholds[:degraded_latency_ms]
                     :degraded
                   else
                     :degraded
                   end

          models = parse_models_response(response)
          details = { model_count: models.size, models: models.map(&:id).first(5) }

          HealthStatus.new(
            status:,
            latency_ms:,
            error: nil,
            checked_at: Time.now,
            model_id:,
            details:
          )
        rescue Faraday::TimeoutError
          latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
          HealthStatus.new(
            status: :unhealthy,
            latency_ms:,
            error: "Request timeout",
            checked_at: Time.now,
            model_id:,
            details: {}
          )
        rescue Faraday::ConnectionFailed => e
          HealthStatus.new(
            status: :unhealthy,
            latency_ms: 0,
            error: "Connection failed: #{e.message}",
            checked_at: Time.now,
            model_id:,
            details: {}
          )
        rescue StandardError => e
          latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
          HealthStatus.new(
            status: :unhealthy,
            latency_ms:,
            error: e.message,
            checked_at: Time.now,
            model_id:,
            details: {}
          )
        end
      end

      # Make a request to the models endpoint
      # Subclasses should override this if they use a different client
      def models_request(timeout: 10)
        # Default implementation for OpenAI-compatible APIs
        if respond_to?(:client, true) && client.respond_to?(:models)
          client.models.list
        elsif instance_variable_defined?(:@client) && @client.respond_to?(:models)
          @client.models.list
        else
          # Fallback to direct HTTP request
          uri = models_endpoint_uri
          conn = Faraday.new do |f|
            f.options.timeout = timeout
            f.adapter Faraday.default_adapter
          end
          response = conn.get(uri) do |req|
            req.headers["Authorization"] = "Bearer #{@api_key}" if @api_key && @api_key != "not-needed"
          end
          JSON.parse(response.body)
        end
      end

      def models_endpoint_uri
        base = @client&.uri_base || @api_base || "https://api.openai.com/v1"
        base = base.sub(%r{/+$}, "")
        "#{base}/models"
      end

      def parse_models_response(response)
        data = response.is_a?(Hash) ? response : response.to_h
        models_data = data["data"] || data[:data] || []

        models_data.map do |m|
          ModelInfo.new(
            id: m["id"] || m[:id],
            object: m["object"] || m[:object] || "model",
            created: m["created"] || m[:created],
            owned_by: m["owned_by"] || m[:owned_by],
            loaded: m["loaded"] || m[:loaded] # Some servers include this
          )
        end
      end

      def client
        @client
      end
    end
  end
end
