require_relative "agent_type"
require_relative "agent_text"
require_relative "agent_image"
require_relative "agent_audio"

module Smolagents
  module Types
    # Maps type strings to AgentType classes for dynamic wrapper instantiation.
    #
    # @return [Hash{String => Class}] Mapping of type names to classes
    # @example
    #   AGENT_TYPE_MAPPING["image"]  # => AgentImage
    AGENT_TYPE_MAPPING = {
      "string" => AgentText,
      "text" => AgentText,
      "image" => AgentImage,
      "audio" => AgentAudio
    }.freeze
  end

  # Helper to convert AgentType instances to raw values for tool input.
  #
  # @param args [Array] Positional arguments
  # @param kwargs [Hash] Keyword arguments
  # @return [Array<Array, Hash>] Converted args and kwargs
  def self.handle_agent_input_types(*args, **kwargs)
    args = args.map { |arg| arg.is_a?(Types::AgentType) ? arg.to_raw : arg }
    kwargs = kwargs.transform_values { |val| val.is_a?(Types::AgentType) ? val.to_raw : val }
    [args, kwargs]
  end

  # Helper to wrap tool output in appropriate AgentType.
  #
  # @param output [Object] Raw tool output
  # @param output_type [String, nil] Expected output type
  # @return [AgentType, Object] Wrapped or original output
  def self.handle_agent_output_types(output, output_type: nil)
    return Types::AGENT_TYPE_MAPPING[output_type].new(output) if output_type && Types::AGENT_TYPE_MAPPING[output_type]

    case output
    when String then Types::AgentText.new(output)
    else output
    end
  end
end
