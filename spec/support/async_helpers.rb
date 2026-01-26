# Helpers for testing async/concurrent code without using sleep
module AsyncHelpers
  # Wait for a condition to become true with fast polling.
  # Much faster than fixed sleep - returns immediately when condition is met.
  #
  # @param timeout [Float] Maximum time to wait in seconds (default: 0.1)
  # @param interval [Float] Polling interval in seconds (default: 0.001 = 1ms)
  # @yield Block that returns truthy when condition is met
  # @return [Boolean] true if condition was met, false if timeout
  #
  # @example Wait for a value to be set
  #   result = nil
  #   Thread.new { result = compute_something }
  #   wait_for { result }
  #   expect(result).to eq(expected)
  #
  # @example Wait with custom timeout
  #   wait_for(timeout: 0.5) { slow_operation_complete? }
  #
  def wait_for(timeout: 0.1, interval: 0.001)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      return true if yield
      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep interval # rubocop:disable Smolagents/NoSleep -- core async helper
    end
  end

  # Simulate async work completion with minimal delay.
  # Use when you need a thread to do something that takes "some" time.
  # Returns immediately if no delay needed.
  #
  # @param duration [Float] Simulated work duration in seconds
  def simulate_work(duration = 0.001)
    return if duration <= 0

    sleep duration # rubocop:disable Smolagents/NoSleep -- simulating work
  end
end

RSpec.configure do |config|
  config.include AsyncHelpers
end
