# Traced Model Wrapper
#
# Wraps a model to capture raw prompts and responses for debugging.
# Used by the experiment runner to log full LLM interactions.

module LiveExperiments
  class TracedModel
    attr_reader :model, :traces

    def initialize(model)
      @model = model
      @traces = []
      @mutex = Mutex.new
    end

    # Delegate all model methods to the wrapped model
    def method_missing(method, *, **, &)
      if @model.respond_to?(method)
        @model.send(method, *, **, &)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @model.respond_to?(method, include_private) || super
    end

    # Override generate to capture raw I/O
    def generate(messages, **options)
      trace_id = SecureRandom.hex(8)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Capture the prompt
      prompt_data = {
        trace_id: trace_id,
        type: :prompt,
        timestamp: Time.now.iso8601,
        model_id: model_id,
        messages: serialize_messages(messages),
        options: sanitize_options(options)
      }

      begin
        # Call the underlying model
        response = @model.generate(messages, **options)

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).to_i

        # Capture the response
        response_data = {
          trace_id: trace_id,
          type: :response,
          timestamp: Time.now.iso8601,
          model_id: model_id,
          duration_ms: duration_ms,
          content: serialize_response(response),
          raw_content: extract_raw_content(response),
          tool_calls: extract_tool_calls(response),
          token_usage: extract_token_usage(response),
          success: true
        }

        record_trace(prompt_data, response_data)
        response

      rescue StandardError => e
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).to_i

        # Capture the error
        error_data = {
          trace_id: trace_id,
          type: :error,
          timestamp: Time.now.iso8601,
          model_id: model_id,
          duration_ms: duration_ms,
          error_class: e.class.name,
          error_message: e.message,
          success: false
        }

        record_trace(prompt_data, error_data)
        raise
      end
    end

    # Get the model_id from the wrapped model
    def model_id
      @model.respond_to?(:model_id) ? @model.model_id : "unknown"
    end

    # Clear traces
    def clear_traces!
      @mutex.synchronize { @traces.clear }
    end

    # Get traces and optionally clear
    def drain_traces
      @mutex.synchronize do
        result = @traces.dup
        @traces.clear
        result
      end
    end

    private

    def record_trace(prompt, response)
      @mutex.synchronize do
        @traces << { prompt: prompt, response: response }
      end
    end

    def serialize_messages(messages)
      messages.map do |msg|
        case msg
        when Hash
          msg.transform_keys(&:to_s)
        when Smolagents::Types::ChatMessage
          {
            "role" => msg.role.to_s,
            "content" => truncate_content(msg.content),
            "tool_calls" => msg.tool_calls&.map { |tc| serialize_tool_call(tc) },
            "images" => msg.images&.any? ? "[#{msg.images.size} images]" : nil
          }.compact
        else
          { "raw" => truncate_content(msg.to_s) }
        end
      end
    end

    def serialize_tool_call(tc)
      return nil unless tc

      {
        "id" => tc.respond_to?(:id) ? tc.id : nil,
        "name" => tc.respond_to?(:name) ? tc.name : nil,
        "arguments" => tc.respond_to?(:arguments) ? tc.arguments : nil
      }.compact
    end

    def serialize_response(response)
      case response
      when Smolagents::Types::ChatMessage
        truncate_content(response.content)
      when String
        truncate_content(response)
      else
        truncate_content(response.to_s)
      end
    end

    def extract_tool_calls(response)
      return nil unless response.respond_to?(:tool_calls)

      response.tool_calls&.map { |tc| serialize_tool_call(tc) }
    end

    def extract_raw_content(response)
      return nil unless response.respond_to?(:raw)
      return nil unless response.raw

      # The raw field contains the original API response
      raw = response.raw
      if raw.is_a?(Hash)
        # OpenAI format
        content = raw.dig("choices", 0, "message", "content")
        truncate_content(content) if content
      else
        truncate_content(raw.to_s)
      end
    end

    def extract_token_usage(response)
      return nil unless response.respond_to?(:token_usage)
      return nil unless response.token_usage

      tu = response.token_usage
      {
        input_tokens: tu.respond_to?(:input_tokens) ? tu.input_tokens : nil,
        output_tokens: tu.respond_to?(:output_tokens) ? tu.output_tokens : nil
      }.compact
    end

    def sanitize_options(options)
      # Remove tools_to_call_from as it's verbose
      options.except(:tools_to_call_from).transform_values do |v|
        case v
        when Array then v.size
        when Hash then v.keys
        else v
        end
      end
    end

    def truncate_content(content, max_length: 10_000)
      return nil if content.nil?

      str = content.to_s
      str.length > max_length ? "#{str[0...max_length]}... [TRUNCATED #{str.length - max_length} chars]" : str
    end
  end
end
