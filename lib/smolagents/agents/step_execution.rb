module Smolagents
  module StepExecution
    def with_step_timing(step_number: 0)
      builder = ActionStepBuilder.new(step_number: step_number)

      begin
        yield builder
      rescue StandardError => e
        builder.error = "#{e.class}: #{e.message}"
        @logger.error("Step error", error: e.message)
      end

      builder.timing = builder.timing.stop
      builder.build
    end
  end
end
