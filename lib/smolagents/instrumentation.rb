module Smolagents
  #
  #
  #
  #
  #
  #
  #
  module Instrumentation
    class << self
      attr_accessor :subscriber

      #
      #
      #
      def instrument(event, payload = {})
        return yield unless subscriber

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

        subscriber.call(event, payload.merge(duration: duration))
        result
      rescue StandardError => e
        duration = start_time ? (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) : 0

        subscriber&.call(event, payload.merge(error: e.class.name, duration: duration))
        raise
      end
    end
  end
end
