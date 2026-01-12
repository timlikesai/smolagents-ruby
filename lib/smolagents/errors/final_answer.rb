module Smolagents
  class FinalAnswerException < StandardError
    attr_reader :value

    def initialize(value)
      @value = value
      super("Final answer: #{value.inspect}")
    end
  end
end
