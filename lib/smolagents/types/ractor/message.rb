module Smolagents
  module Types
    module Ractor
      # Valid message types for Ractor communication
      RACTOR_MESSAGE_TYPES = %i[task result].freeze

      # Message envelope for type-safe Ractor communication.
      #
      # @example Sending a task
      #   message = Types::RactorMessage.task(task)
      #   ractor.send(message)
      RactorMessage = Data.define(:type, :payload) do
        # Creates a RactorMessage containing a task.
        #
        # @param task [RactorTask] the task to wrap
        # @return [RactorMessage] a message with type: :task
        def self.task(task) = new(type: :task, payload: task)

        # Creates a RactorMessage containing a result.
        #
        # @param result [RactorSuccess, RactorFailure] the result to wrap
        # @return [RactorMessage] a message with type: :result
        def self.result(result) = new(type: :result, payload: result)

        def task? = type == :task
        def result? = type == :result

        # Deconstructs the message for pattern matching.
        #
        # @param _ [Object] ignored
        # @return [Hash{Symbol => Object}] hash with message type and payload
        def deconstruct_keys(_) = { type:, payload: }
      end
    end

    # Re-export at Types level for backwards compatibility
    RACTOR_MESSAGE_TYPES = Ractor::RACTOR_MESSAGE_TYPES
    RactorMessage = Ractor::RactorMessage
  end
end
