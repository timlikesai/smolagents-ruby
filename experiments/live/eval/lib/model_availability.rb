# Model Availability Detection
#
# Classifies model errors and detects availability before running tests.
# Distinguishes between "model not loaded" vs "test failed" scenarios.

module LiveExperiments
  module Eval
    # Error types for model availability issues
    class ModelNotLoadedError < StandardError
      attr_reader :model_id, :available_models

      def initialize(model_id, available_models = [])
        @model_id = model_id
        @available_models = available_models
        super("Model '#{model_id}' not loaded. Available: #{available_models.join(', ')}")
      end
    end

    class InsufficientMemoryError < StandardError
      attr_reader :model_id, :details

      def initialize(model_id, details = nil)
        @model_id = model_id
        @details = details
        super("Insufficient memory to load '#{model_id}'#{details ? ": #{details}" : ''}")
      end
    end

    class ModelLoadingError < StandardError
      attr_reader :model_id, :reason

      def initialize(model_id, reason)
        @model_id = model_id
        @reason = reason
        super("Failed to load '#{model_id}': #{reason}")
      end
    end

    # Detects model availability and classifies errors
    class ModelAvailability
      include Smolagents::Concerns::Http

      def initialize(endpoint)
        @endpoint = endpoint
      end

      # Check if a specific model is available
      # @param model_id [String] Model ID to check
      # @return [Hash] { available: bool, models: [], error: nil|Error }
      def check(model_id)
        available_models = fetch_models

        if available_models.include?(model_id)
          { available: true, models: available_models, error: nil }
        else
          error = ModelNotLoadedError.new(model_id, available_models)
          { available: false, models: available_models, error: error }
        end
      rescue StandardError => e
        { available: false, models: [], error: e }
      end

      # Verify model can generate (warm check with classify errors)
      # @param model [Smolagents::Models::OpenAIModel] Model instance
      # @return [Hash] { ready: bool, load_time_ms: int, error: nil|Error }
      def verify_ready(model)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        message = Smolagents::Types::ChatMessage.user("Say 'ready'")

        Timeout.timeout(120) { model.generate([message]) }

        load_time = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
        { ready: true, load_time_ms: load_time, error: nil }
      rescue Timeout::Error
        { ready: false, load_time_ms: nil, error: ModelLoadingError.new(model.model_id, "Timeout after 120s") }
      rescue Faraday::BadRequestError => e
        error = classify_400_error(model.model_id, e)
        { ready: false, load_time_ms: nil, error: error }
      rescue StandardError => e
        { ready: false, load_time_ms: nil, error: e }
      end

      private

      def fetch_models
        response = get("#{@endpoint}/models", headers: {}, allow_private: true, timeout: 5.0)
        JSON.parse(response.body)["data"]&.map { |m| m["id"] } || []
      end

      # Parse 400 error bodies to classify the failure
      def classify_400_error(model_id, error)
        body = parse_error_body(error)
        message = body["error"]&.fetch("message", "") || body["message"] || ""

        case message.downcase
        when /insufficient.*memory|out of memory|oom|cannot allocate/
          InsufficientMemoryError.new(model_id, message)
        when /not found|no model|model.*not.*loaded/
          available = fetch_models rescue []
          ModelNotLoadedError.new(model_id, available)
        when /loading|starting|initializing/
          ModelLoadingError.new(model_id, "Model is still loading")
        else
          ModelLoadingError.new(model_id, message)
        end
      end

      def parse_error_body(error)
        return {} unless error.respond_to?(:response) && error.response

        body = error.response[:body]
        return {} unless body

        JSON.parse(body)
      rescue JSON::ParserError
        { "message" => body.to_s }
      end
    end
  end
end
