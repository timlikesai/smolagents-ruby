module Smolagents
  class Model
    attr_accessor :logger
    attr_reader :model_id

    def initialize(model_id:, **kwargs)
      @model_id = model_id
      @kwargs = kwargs
      @logger = nil
    end

    def generate(_messages, stop_sequences: nil, response_format: nil, tools_to_call_from: nil, **_kwargs)
      raise NotImplementedError, "#{self.class}#generate must be implemented"
    end

    def generate_stream(messages, **)
      return enum_for(:generate_stream, messages, **) unless block_given?

      raise NotImplementedError, "#{self.class}#generate_stream must be implemented"
    end

    def parse_tool_calls(message) = message
    def call(*, **) = generate(*, **)

    def validate_required_params(required, kwargs)
      missing = required - kwargs.keys
      raise ArgumentError, "Missing required parameters: #{missing.join(", ")}" unless missing.empty?
    end
  end
end
