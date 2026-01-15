module Smolagents
  module Types
    # Text data type for agent communication.
    #
    # Wraps string content for consistent handling with other agent types.
    #
    # @example Creating text
    #   text = Types::AgentText.new("Hello, world!")
    #   text.length  # => 13
    #
    # @example String operations
    #   combined = AgentText.new("Hello") + AgentText.new(" world")
    #   combined.to_s  # => "Hello world"
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
