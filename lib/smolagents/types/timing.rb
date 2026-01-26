module Smolagents
  module Types
    # Immutable timing information for an operation.
    #
    # Records when an operation started and stopped, with convenient methods
    # for measuring duration. Used throughout the system for performance monitoring.
    #
    # @!attribute [r] start_time
    #   @return [Time] When the operation started
    # @!attribute [r] end_time
    #   @return [Time, nil] When the operation ended (nil if still running)
    #
    # @example Timing an operation
    #   timing = Smolagents::Types::Timing.start_now
    #   timing.end_time.nil?  # => true
    #   timing = timing.stop
    #   timing.end_time.nil?  # => false
    #
    # @see ActionStep#timing For step-level timing
    # @see ExecutionOutcome#duration For operation duration
    Timing = Data.define(:start_time, :end_time) do
      include TypeSupport::Deconstructable
      include TypeSupport::Serializable
      extend TypeSupport::FactoryBuilder

      calculated_field :duration, -> { end_time && (end_time - start_time) }

      factory :start_now, start_time: Time.now, end_time: nil

      # Creates a Timing with current time as start and nil end.
      #
      # @return [Timing] Timing starting now, not yet stopped
      def self.start_now = new(start_time: Time.now, end_time: nil)

      # Marks the end time as now, returning a new Timing.
      #
      # @return [Timing] New timing with end_time set to current time
      def stop = self.class.new(start_time:, end_time: Time.now)

      # Calculates elapsed time in seconds.
      #
      # @return [Float, nil] Duration in seconds, or nil if not stopped
      def duration = end_time && (end_time - start_time)
    end
  end
end
