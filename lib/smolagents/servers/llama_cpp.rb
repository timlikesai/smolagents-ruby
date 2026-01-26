module Smolagents
  module Servers
    # Client for llama.cpp server in router mode.
    #
    # The llama.cpp router manages multiple models with hot-swapping,
    # automatically loading models when requested and unloading when
    # slots are needed.
    #
    # @example Basic usage
    #   server = Smolagents::Servers::LlamaCpp.new(
    #     api_base: "https://llama-cpp.example.com"
    #   )
    #
    #   # List all models with status
    #   server.models.each { |m| puts "#{m.id}: #{m.status}" }
    #
    #   # Get a model ready for use
    #   model = server.model("gemma-3n-E4B-it-Q8_0")
    #   agent = Smolagents.agent.model { model }.build
    #
    # @example Warmup a model before use
    #   server.warmup("LFM2.5-1.2B-Instruct-Q8_0")
    #   # Model is now loaded and ready
    #
    class LlamaCpp
      # Model info returned from the server.
      ModelInfo = Data.define(:id, :status, :context_size, :failed, :preset) do
        def loaded? = status == "loaded"
        def unloaded? = status == "unloaded"
        def loading? = status == "loading"
        def failed? = failed == true
        def ready? = loaded? && !failed?
      end

      # Slot info for a loaded model.
      SlotInfo = Data.define(:id, :context_size, :speculative, :processing)

      attr_reader :api_base, :api_key, :timeout

      # @param api_base [String] Base URL (e.g., "https://llama-cpp.example.com")
      # @param api_key [String, nil] API key if required
      # @param timeout [Integer] HTTP timeout in seconds (default: 30)
      def initialize(api_base:, api_key: nil, timeout: 30)
        @api_base = api_base.chomp("/")
        @api_key = api_key
        @timeout = timeout
      end

      # List all models with their status.
      #
      # @return [Array<ModelInfo>] All configured models
      def models
        response = get("/v1/models")
        response["data"].map { |m| parse_model_info(m) }
      end

      # @return [Array<String>] Model IDs
      def model_ids = models.map(&:id)

      # @return [Array<ModelInfo>] Loaded models
      def loaded_models = models.select(&:loaded?)

      # @param model_id [String] Model identifier
      # @return [ModelInfo, nil] Model info or nil if not found
      def model_status(model_id) = models.find { |m| m.id == model_id }

      # @param model_id [String] Model identifier
      # @return [Boolean] True if model is loaded and ready
      def ready?(model_id) = model_status(model_id)&.ready? || false

      # Get slot information for a loaded model.
      # @param model_id [String] Model identifier
      # @return [Array<SlotInfo>] Slot information
      # @raise [ArgumentError] If model is not loaded
      def slots(model_id)
        get("/slots", model: model_id).map { |slot| parse_slot_info(slot) }
      rescue Faraday::BadRequestError => e
        raise ArgumentError, "Model '#{model_id}' is not loaded: #{e.message}"
      end

      # Warmup a model by sending a minimal request.
      #
      # This triggers the router to load the model if not already loaded.
      # Blocks until the model responds.
      #
      # @param model_id [String] Model identifier
      # @param timeout [Integer] Warmup timeout in seconds (default: 120)
      # @return [ModelInfo] Updated model status
      def warmup(model_id, timeout: 120)
        post("/v1/chat/completions", {
               model: model_id,
               messages: [{ role: "user", content: "hi" }],
               max_tokens: 1
             }, timeout:)
        model_status(model_id)
      end

      # Create an OpenAIModel configured for this server.
      #
      # @param model_id [String] Model identifier
      # @param max_tokens [Integer] Max response tokens (default: 8192)
      # @param options [Hash] Additional OpenAIModel options
      # @return [Models::OpenAIModel] Configured model
      def model(model_id, max_tokens: 8192, **)
        Models::OpenAIModel.new(
          model_id:,
          api_base: "#{@api_base}/v1",
          api_key: @api_key || "not-needed",
          max_tokens:,
          **
        )
      end

      # Server health check.
      #
      # @return [Boolean] True if server is healthy
      def healthy?
        response = get("/health")
        response["status"] == "ok"
      rescue StandardError
        false
      end

      private

      def parse_model_info(data)
        status = data.dig("status", "value") || "unknown"
        ModelInfo.new(
          id: data["id"],
          status:,
          context_size: extract_context_size(data),
          failed: data.dig("status", "failed") || false,
          preset: data.dig("status", "preset")
        )
      end

      def extract_context_size(data)
        args = data.dig("status", "args") || []
        ctx_idx = args.index("--ctx-size")
        ctx_idx ? args[ctx_idx + 1].to_i : nil
      end

      def parse_slot_info(slot)
        SlotInfo.new(id: slot["id"], context_size: slot["n_ctx"],
                     speculative: slot["speculative"], processing: slot["is_processing"])
      end

      def get(path, **params)
        url = "#{@api_base}#{path}"
        url += "?#{URI.encode_www_form(params)}" unless params.empty?
        response = connection.get(url)
        body = JSON.parse(response.body)
        raise Faraday::BadRequestError, body.dig("error", "message") if body.is_a?(Hash) && body["error"]

        body
      end

      def post(path, body, timeout: @timeout)
        url = "#{@api_base}#{path}"
        response = connection(timeout).post(url) do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = JSON.generate(body)
        end
        JSON.parse(response.body)
      end

      def connection(timeout = @timeout)
        Faraday.new do |f|
          f.options.timeout = timeout
          f.options.open_timeout = 10
          f.headers["Authorization"] = "Bearer #{@api_key}" if @api_key
          f.adapter Faraday.default_adapter
        end
      end
    end
  end
end
