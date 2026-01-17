module Smolagents
  module Types
    # Text data type for agent communication.
    #
    # Wraps string content for consistent handling with other agent types.
    # Provides string-like operations while maintaining type safety.
    #
    # @example Creating text
    #   text = Smolagents::Types::AgentText.new("Hello, world!")
    #   text.length  # => 13
    #   text.empty?  # => false
    #
    # @example String operations
    #   a = Smolagents::Types::AgentText.new("Hello")
    #   b = Smolagents::Types::AgentText.new(" world")
    #   combined = a + b
    #   combined.to_s  # => "Hello world"
    #
    # @example Serialization
    #   text = Smolagents::Types::AgentText.new("content")
    #   text.to_h  # => { type: "agenttext", value: "content" }
    #
    # @see AgentType Base class for agent types
    # @see AgentImage For image data
    # @see AgentAudio For audio data
    class AgentText < AgentType
      # Returns raw string value.
      # @return [String]
      def to_raw = value.to_s

      # Returns string representation.
      # @return [String]
      def to_string = value.to_s

      # Concatenates two AgentText objects.
      # @param other [AgentText, #to_s]
      # @return [AgentText]
      def +(other) = AgentText.new(value.to_s + other.to_s)

      # Returns the length of the text.
      # @return [Integer]
      def length = value.to_s.length

      # Checks if text is empty.
      # @return [Boolean]
      def empty? = value.to_s.empty?

      # Checks equality with another text object.
      # @param other [AgentText, #to_s]
      # @return [Boolean]
      def ==(other) = to_string == other.to_s
    end
  end
end
