module Smolagents
  class OperationCounter
    def initialize(max_operations)
      @max_operations = max_operations
      @operations = 0
      @trace = nil
    end

    def start
      @operations = 0
      @trace = TracePoint.new(:line) do
        @operations += 1
        if @operations > @max_operations
          @trace&.disable
          raise InterpreterError, "Operation limit exceeded: #{@max_operations}"
        end
      end
      @trace.enable
    end

    def stop = @trace&.disable

    def with_limit
      start
      yield
    ensure
      stop
    end
  end
end
