module Smolagents
  module Testing
    # Trace agent behavior using Ruby's TracePoint.
    #
    # Records method calls during agent execution for verification
    # without requiring explicit assertions.
    #
    # @example Trace agent execution
    #   tracer = BehaviorTracer.new
    #   trace = tracer.trace { agent.run("Do something") }
    #
    #   expect(trace.called?(:generate)).to be true
    #   expect(trace.call_count(:execute)).to eq(2)
    class BehaviorTracer
      # @param filter [Regexp, String, nil] Filter traced classes
      # @param tracer_factory [#call, nil] Factory for creating tracer (for testing)
      def initialize(filter: /Smolagents/, tracer_factory: nil)
        @filter = filter.is_a?(Regexp) ? filter : /#{filter}/
        @traces = []
        @tracer_factory = tracer_factory
      end

      # Execute a block while tracing method calls.
      #
      # @yield Block to trace
      # @return [Trace] Recorded trace data
      def trace
        @traces = []
        tp = @tracer_factory&.call || build_tracepoint

        tp.enable
        result = yield
        tp.disable

        Trace.new(events: @traces.dup, result:)
      end

      # Add a trace event (used by injected tracers for testing).
      # @api private
      def add_trace(event) = @traces << event

      private

      def build_tracepoint
        TracePoint.new(:call, :return) { |tp| record_trace(tp) if tp.defined_class.to_s.match?(@filter) }
      end

      def record_trace(tracepoint)
        @traces << TraceEvent.new(
          event_type: tracepoint.event, method_name: tracepoint.method_id, class_name: tracepoint.defined_class.to_s,
          timestamp: Process.clock_gettime(Process::CLOCK_MONOTONIC), path: tracepoint.path, lineno: tracepoint.lineno
        )
      end
    end

    # A single traced event
    TraceEvent = Data.define(:event_type, :method_name, :class_name, :timestamp, :path, :lineno) do
      def call? = event_type == :call
      def return? = event_type == :return
      def to_s = "#{class_name}##{method_name} (#{event_type})"
    end

    # Recorded trace from a BehaviorTracer session
    Trace = Data.define(:events, :result) do
      # Check if a method was called
      def called?(method_name)
        events.any? { |e| e.method_name == method_name && e.call? }
      end

      # Count method calls
      def call_count(method_name)
        events.count { |e| e.method_name == method_name && e.call? }
      end

      # Get unique methods called in order
      def call_order
        events.select(&:call?).map(&:method_name).uniq
      end

      # Get all calls to a specific method
      def calls_to(method_name)
        events.select { |e| e.method_name == method_name && e.call? }
      end

      # Check if methods were called in order
      def called_in_order?(*method_names)
        order = call_order
        method_names.each_cons(2).all? do |a, b|
          idx_a = order.index(a)
          idx_b = order.index(b)
          idx_a && idx_b && idx_a < idx_b
        end
      end

      # Get call sequence as strings
      def call_sequence
        events.select(&:call?).map(&:to_s)
      end

      # Duration of the traced execution
      def duration
        return 0 if events.empty?

        events.last.timestamp - events.first.timestamp
      end
    end
  end
end
