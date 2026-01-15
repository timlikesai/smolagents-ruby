module Smolagents
  module Executors
    # Signal for final answer in Ractor context.
    #
    # Used instead of FinalAnswerException in Ractor context because exceptions
    # cannot be safely passed across Ractor boundaries. This custom signal is
    # caught and handled to trigger final answer behavior.
    #
    # @example
    #   raise FinalAnswerSignal, "The answer is 42"
    #
    # @see FinalAnswerException For LocalRuby context
    class FinalAnswerSignal < StandardError
      # The final answer value.
      # @return [Object] The value passed to the signal
      attr_reader :value

      # @param value [Object] The final answer value
      def initialize(value)
        @value = value
        super("Final answer")
      end
    end
  end
end
