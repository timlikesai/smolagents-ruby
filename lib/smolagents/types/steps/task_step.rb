module Smolagents
  module Types
    # Immutable step representing a task given to the agent.
    #
    # TaskStep captures the user's request along with any attached images.
    # It appears at the start of a run and may appear again if the user
    # provides follow-up tasks. Tasks are the entry points for agent execution.
    #
    # @example Creating a task step
    #   step = Types::TaskStep.new(task: "Calculate 2+2")
    #   step.to_messages  # => [ChatMessage.user("Calculate 2+2")]
    #
    # @example With image attachments
    #   step = Types::TaskStep.new(
    #     task: "Describe this image",
    #     task_images: ["/path/to/image.jpg"]
    #   )
    #
    # @see AgentMemory#add_task Creates task steps in memory
    # @see Agents#run Processes task steps to produce results
    TaskStep = Data.define(:task, :task_images) do
      # Creates a new TaskStep with the given task and optional images.
      #
      # @param task [String] The user's task or request
      # @param task_images [Array<String>, nil] Image paths or URLs to attach to task
      # @return [TaskStep] Initialized immutable step
      def initialize(task:, task_images: nil) = super

      # Converts the task step to a hash for serialization.
      #
      # @return [Hash] Hash with :task and optional :task_images count
      def to_h = { task:, task_images: task_images&.length }.compact

      # Converts task step to chat messages for LLM context.
      #
      # @param _opts [Hash] Options (ignored for task steps)
      # @return [Array<ChatMessage>] Single user message containing the task
      def to_messages(**_opts) = [ChatMessage.user(task, images: task_images&.any? ? task_images : nil)]

      # Enables pattern matching with `in TaskStep[task:, task_images:]`.
      #
      # @param keys [Array, nil] Keys to extract (ignored, returns all)
      # @return [Hash] All fields as a hash
      def deconstruct_keys(_keys) = to_h
    end
  end
end
