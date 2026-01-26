require "spec_helper"

# rubocop:disable RSpec/DescribeClass -- integration test
RSpec.describe "Event-driven integration" do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:orchestrator) { Smolagents::Orchestrators::EventOrchestrator.new }

  after { orchestrator.stop if orchestrator.running? }

  describe "full async execution flow" do
    it "completes a task asynchronously with callbacks" do
      mock_model.queue_final_answer("integration result")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .event_driven
                        .build

      result_queue = Queue.new
      agent.run_async("Complete this task",
                      on_complete: ->(result) { result_queue.push(result) })

      # Block until result arrives
      final_result = result_queue.pop
      expect(final_result).to be_a(Smolagents::Types::RunResult)
      expect(final_result.output).to eq("integration result")
    end

    it "tracks step progress via callbacks" do
      mock_model.queue_code_action('puts "step 1"')
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .event_driven
                        .build

      step_queue = Queue.new
      complete_queue = Queue.new

      agent.run_async("Multi-step task",
                      on_step: ->(s) { step_queue.push(s) },
                      on_complete: ->(r) { complete_queue.push(r) })

      # Wait for completion
      complete_queue.pop
      expect(step_queue.size).to be >= 1
    end
  end

  describe "orchestrator integration" do
    before { orchestrator.start }

    it "routes events through orchestrator" do
      mock_model.queue_final_answer("orchestrated result")

      event_queue = Queue.new
      orchestrator.subscribe(:step_complete) { |e| event_queue.push(e) }

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .orchestrator(orchestrator)
                        .build

      result_queue = Queue.new
      agent.run_async("Orchestrated task", on_complete: ->(r) { result_queue.push(r) })

      # Wait for completion
      result_queue.pop

      # Events should be routed through orchestrator
      expect(event_queue.size).to be >= 1
    end

    it "maintains agent-orchestrator connection" do
      mock_model.queue_final_answer("connected")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .orchestrator(orchestrator)
                        .build

      expect(agent.async_stats[:orchestrator_connected]).to be true
    end
  end

  describe "error handling" do
    it "handles errors gracefully and continues to completion" do
      mock_model.queue_code_action("def broken_code\n  raise 'test error'\nend\nbroken_code")
      mock_model.queue_final_answer("recovered")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .event_driven
                        .build

      result_queue = Queue.new
      run_id = agent.run_async("Task that might fail",
                               on_complete: ->(r) { result_queue.push(r) })

      # Verify run started and completes
      expect(run_id).to be_a(String)
      result = result_queue.pop
      expect(result.output).to eq("recovered")
    end
  end

  describe "cancellation" do
    it "can cancel running async tasks" do
      # Queue responses but we'll cancel before completion
      mock_model.queue_final_answer("should not reach")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .event_driven
                        .build

      run_id = agent.run_async("Task to cancel")
      agent.cancel_run(run_id)

      expect(agent.async_running?(run_id)).to be false
    end
  end

  describe "multiple sequential runs" do
    it "handles multiple async runs sequentially" do
      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .event_driven
                        .build

      result_queue = Queue.new

      # First run
      mock_model.queue_final_answer("result 1")
      agent.run_async("Task 1", on_complete: ->(r) { result_queue.push(r.output) })
      first_result = result_queue.pop

      # Second run after first completes
      mock_model.queue_final_answer("result 2")
      agent.run_async("Task 2", on_complete: ->(r) { result_queue.push(r.output) })
      second_result = result_queue.pop

      expect([first_result, second_result]).to contain_exactly("result 1", "result 2")
    end
  end
end
# rubocop:enable RSpec/DescribeClass
