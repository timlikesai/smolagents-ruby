RSpec.describe "Instrumentation Integration" do
  after do
    Smolagents::Instrumentation.subscriber = nil
  end

  describe "Tool execution instrumentation" do
    let(:test_tool_class) do
      Class.new(Smolagents::Tool) do
        self.tool_name = "test_tool"
        self.description = "A test tool"
        self.inputs = {
          "query" => { "type" => "string", "description" => "Search query" }
        }
        self.output_type = "string"

        def execute(query:)
          "Result for: #{query}"
        end
      end
    end

    it "emits events when tool is called" do
      events = []
      Smolagents::Instrumentation.subscriber = lambda do |event, payload|
        events << { event: event, payload: payload }
      end

      tool = test_tool_class.new
      result = tool.call(query: "test query")

      expect(result.data).to eq("Result for: test query")
      expect(events.length).to eq(1)
      expect(events[0][:event]).to eq("smolagents.tool.call")
      expect(events[0][:payload][:tool_name]).to eq("test_tool")
      expect(events[0][:payload][:tool_class]).to eq(test_tool_class.name)
      expect(events[0][:payload][:duration]).to be_a(Numeric)
      expect(events[0][:payload][:duration]).to be >= 0
    end

    it "emits error events when tool fails" do
      failing_tool_class = Class.new(Smolagents::Tool) do
        self.tool_name = "failing_tool"
        self.description = "A failing tool"
        self.inputs = {}
        self.output_type = "string"

        def execute
          raise StandardError, "Tool failed"
        end
      end

      events = []
      Smolagents::Instrumentation.subscriber = lambda do |event, payload|
        events << { event: event, payload: payload }
      end

      tool = failing_tool_class.new

      expect { tool.call }.to raise_error(StandardError, "Tool failed")

      expect(events.length).to eq(1)
      expect(events[0][:event]).to eq("smolagents.tool.call")
      expect(events[0][:payload][:error]).to eq("StandardError")
      expect(events[0][:payload][:duration]).to be_a(Numeric)
    end
  end

  describe "Executor instrumentation" do
    let(:executor) { Smolagents::LocalRubyExecutor.new }

    it "emits events when executing code" do
      events = []
      Smolagents::Instrumentation.subscriber = lambda do |event, payload|
        events << { event: event, payload: payload }
      end

      result = executor.execute("1 + 1", language: :ruby)

      expect(result.success?).to be true
      expect(result.output).to eq(2)
      expect(events.length).to eq(1)
      expect(events[0][:event]).to eq("smolagents.executor.execute")
      expect(events[0][:payload][:executor_class]).to eq("Smolagents::LocalRubyExecutor")
      expect(events[0][:payload][:language]).to eq(:ruby)
      expect(events[0][:payload][:duration]).to be_a(Numeric)
    end

    it "emits error events when execution fails" do
      events = []
      Smolagents::Instrumentation.subscriber = lambda do |event, payload|
        events << { event: event, payload: payload }
      end

      result = executor.execute("raise 'Error'", language: :ruby)

      expect(result.failure?).to be true
      expect(events.length).to eq(1)
      expect(events[0][:event]).to eq("smolagents.executor.execute")
      expect(events[0][:payload][:duration]).to be_a(Numeric)
    end
  end

  describe "Multiple component instrumentation" do
    it "tracks events from multiple components" do
      events = []
      Smolagents::Instrumentation.subscriber = lambda do |event, payload|
        events << { event: event, tool: payload[:tool_name], executor: payload[:executor_class] }
      end

      tool_class = Class.new(Smolagents::Tool) do
        self.tool_name = "multi_tool"
        self.description = "Multi test tool"
        self.inputs = {}
        self.output_type = "string"

        def execute
          "tool result"
        end
      end

      tool = tool_class.new
      tool.call

      executor = Smolagents::LocalRubyExecutor.new
      executor.execute("42", language: :ruby)

      expect(events.length).to eq(2)
      expect(events[0][:event]).to eq("smolagents.tool.call")
      expect(events[0][:tool]).to eq("multi_tool")
      expect(events[1][:event]).to eq("smolagents.executor.execute")
      expect(events[1][:executor]).to eq("Smolagents::LocalRubyExecutor")
    end
  end

  describe "Metrics collection patterns" do
    it "can collect Prometheus-style metrics" do
      histogram_observations = []
      counter_increments = []

      Smolagents::Instrumentation.subscriber = lambda do |event, payload|
        case event
        when "smolagents.tool.call"
          histogram_observations << { tool: payload[:tool_name], duration: payload[:duration] }
          counter_increments << { tool: payload[:tool_name], labels: { tool: payload[:tool_name] } }
        end
      end

      tool_class = Class.new(Smolagents::Tool) do
        self.tool_name = "prom_tool"
        self.description = "Prometheus test tool"
        self.inputs = {}
        self.output_type = "string"

        def execute
          "result"
        end
      end

      tool = tool_class.new
      tool.call

      expect(histogram_observations.length).to eq(1)
      expect(histogram_observations[0][:tool]).to eq("prom_tool")
      expect(histogram_observations[0][:duration]).to be >= 0

      expect(counter_increments.length).to eq(1)
      expect(counter_increments[0][:tool]).to eq("prom_tool")
    end

    it "can collect StatsD-style metrics" do
      measures = []
      increments = []

      Smolagents::Instrumentation.subscriber = lambda do |event, payload|
        measures << { name: "smolagents.#{event}", value: payload[:duration] * 1000 }
        increments << { name: "smolagents.#{event}.count" }
      end

      executor = Smolagents::LocalRubyExecutor.new
      executor.execute("42", language: :ruby)

      expect(measures.length).to eq(1)
      expect(measures[0][:name]).to eq("smolagents.smolagents.executor.execute")
      expect(measures[0][:value]).to be >= 0

      expect(increments.length).to eq(1)
      expect(increments[0][:name]).to eq("smolagents.smolagents.executor.execute.count")
    end

    it "can track error rates" do
      errors = []
      successes = []

      Smolagents::Instrumentation.subscriber = lambda do |event, payload|
        if payload[:error]
          errors << { event: event, error: payload[:error] }
        else
          successes << { event: event }
        end
      end

      success_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "success_tool"
        self.description = "Success tool"
        self.inputs = {}
        self.output_type = "string"

        def execute
          "success"
        end
      end

      error_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "error_tool"
        self.description = "Error tool"
        self.inputs = {}
        self.output_type = "string"

        def execute
          raise StandardError, "failure"
        end
      end

      success_tool.new.call
      begin
        error_tool.new.call
      rescue StandardError
        nil
      end
      success_tool.new.call

      expect(successes.length).to eq(2)
      expect(errors.length).to eq(1)
      expect(errors[0][:error]).to eq("StandardError")

      total = successes.length + errors.length
      error_rate = errors.length.to_f / total
      expect(error_rate).to be_within(0.01).of(0.333)
    end
  end
end
