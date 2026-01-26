module Smolagents
  module Models
    class Model
      # Callable interface for Model instances.
      #
      # Enables using the model with Ruby's call syntax: model.(messages)
      module Callable
        # Alias for {#generate} enabling a callable interface.
        #
        # Allows the model to be used with Ruby's call syntax:
        #   response = model.(messages)
        #
        # @param args [Array] Positional arguments passed to {#generate}
        # @param kwargs [Hash] Keyword arguments passed to {#generate}
        # @return [ChatMessage] Same as {#generate}
        def call(*, **) = generate(*, **)
      end
    end
  end
end
