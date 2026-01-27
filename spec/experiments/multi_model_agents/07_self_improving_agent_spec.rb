require "spec_helper"
require_relative "../../../experiments/multi_model_agents/07_self_improving_agent"

RSpec.describe "Experiment: Self-Improving Agent", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "Learning" do
    it "creates from reflection" do
      learning = Experiments::SelfImprovingAgent::Learning.from_reflection(
        task_type: "math",
        outcome: :success,
        reflection: "Breaking down complex problems helps"
      )

      expect(learning.task_type).to eq("math")
      expect(learning.outcome).to eq(:success)
      expect(learning.reflection).to eq("Breaking down complex problems helps")
      expect(learning.strategy_update).to include("Continue")
    end

    it "generates failure strategy" do
      learning = Experiments::SelfImprovingAgent::Learning.from_reflection(
        task_type: "search",
        outcome: :failure,
        reflection: "Query was too broad"
      )

      expect(learning.strategy_update).to include("Adjust")
      expect(learning.strategy_update).to include("Query was too broad")
    end

    it "generates partial strategy" do
      learning = Experiments::SelfImprovingAgent::Learning.from_reflection(
        task_type: "analysis",
        outcome: :partial,
        reflection: "Need more data sources"
      )

      expect(learning.strategy_update).to include("Refine")
    end

    it "determines applicability to tasks" do
      learning = Experiments::SelfImprovingAgent::Learning.from_reflection(
        task_type: "math",
        outcome: :success,
        reflection: "test"
      )

      expect(learning.applicable_to?("Solve this MATH problem")).to be true
      expect(learning.applicable_to?("Write a story")).to be false
    end
  end

  describe "KnowledgeBase" do
    let(:kb) { Experiments::SelfImprovingAgent::KnowledgeBase.new }

    it "stores and retrieves learnings" do
      learning = Experiments::SelfImprovingAgent::Learning.from_reflection(
        task_type: "math",
        outcome: :success,
        reflection: "Check your work"
      )

      kb.store(learning)

      expect(kb.learnings.size).to eq(1)
      expect(kb.learnings.first.reflection).to eq("Check your work")
    end

    it "tracks strategies by task type" do
      kb.store(Experiments::SelfImprovingAgent::Learning.from_reflection(
                 task_type: "math",
                 outcome: :success,
                 reflection: "Strategy 1"
               ))
      kb.store(Experiments::SelfImprovingAgent::Learning.from_reflection(
                 task_type: "math",
                 outcome: :failure,
                 reflection: "Strategy 2"
               ))

      hints = kb.strategy_hints("math")

      # Strategy updates contain the outcome-based prefix, not raw reflection
      expect(hints).to include("Continue") # Success strategy
      expect(hints).to include("Strategy 2") # Failure includes reflection
    end

    it "retrieves relevant learnings for a task" do
      kb.store(Experiments::SelfImprovingAgent::Learning.from_reflection(
                 task_type: "math",
                 outcome: :success,
                 reflection: "Math learning"
               ))
      kb.store(Experiments::SelfImprovingAgent::Learning.from_reflection(
                 task_type: "writing",
                 outcome: :success,
                 reflection: "Writing learning"
               ))

      relevant = kb.relevant_learnings("Help me with math homework")

      expect(relevant.size).to eq(1)
      expect(relevant.first.reflection).to eq("Math learning")
    end

    it "limits returned learnings" do
      5.times do |i|
        kb.store(Experiments::SelfImprovingAgent::Learning.from_reflection(
                   task_type: "test",
                   outcome: :success,
                   reflection: "Learning #{i}"
                 ))
      end

      relevant = kb.relevant_learnings("test task", limit: 2)

      expect(relevant.size).to eq(2)
    end

    it "provides summary statistics" do
      kb.store(Experiments::SelfImprovingAgent::Learning.from_reflection(
                 task_type: "math", outcome: :success, reflection: "a"
               ))
      kb.store(Experiments::SelfImprovingAgent::Learning.from_reflection(
                 task_type: "math", outcome: :failure, reflection: "b"
               ))

      summary = kb.summary

      expect(summary[:total_learnings]).to eq(2)
      expect(summary[:by_outcome]).to eq({ success: 1, failure: 1 })
      expect(summary[:task_types]).to include("math")
    end
  end

  describe "ImprovementMetrics" do
    let(:metrics) { Experiments::SelfImprovingAgent::ImprovementMetrics.new }

    it "tracks evaluations" do
      event = double(
        step_number: 1,
        status: :goal_achieved,
        confidence: 0.9,
        reasoning: "Task complete"
      )

      metrics.track_evaluation(event)

      expect(metrics.evaluations.size).to eq(1)
      expect(metrics.evaluations.first[:confidence]).to eq(0.9)
    end

    it "tracks refinements" do
      event = double(iterations: 2, improved: true, confidence: 0.85)

      metrics.track_refinement(event)

      expect(metrics.refinements.size).to eq(1)
      expect(metrics.refinements.first[:improved]).to be true
    end

    it "tracks reflections" do
      event = double(outcome: :failure, reflection: "Need better approach")

      metrics.track_reflection(event)

      expect(metrics.reflections.size).to eq(1)
      expect(metrics.reflections.first[:outcome]).to eq(:failure)
    end

    it "tracks steps" do
      event = double(step_number: 1, outcome: :success, observations: "Tool executed")

      metrics.track_step(event)

      expect(metrics.steps.size).to eq(1)
      expect(metrics.steps.first[:step_number]).to eq(1)
      expect(metrics.steps.first[:outcome]).to eq(:success)
    end

    it "tracks completions" do
      event = double(outcome: :success, output: "Final result", steps_taken: 3)

      metrics.track_completion(event)

      expect(metrics.completions.size).to eq(1)
      expect(metrics.completions.first[:outcome]).to eq(:success)
      expect(metrics.completions.first[:steps_taken]).to eq(3)
    end

    it "calculates improvement rate" do
      metrics.track_refinement(double(iterations: 1, improved: true, confidence: 0.8))
      metrics.track_refinement(double(iterations: 2, improved: true, confidence: 0.9))
      metrics.track_refinement(double(iterations: 1, improved: false, confidence: 0.7))

      expect(metrics.improvement_rate).to be_within(0.01).of(0.67)
    end

    it "calculates average confidence" do
      metrics.track_evaluation(double(step_number: 1, status: :continue, confidence: 0.6, reasoning: ""))
      metrics.track_evaluation(double(step_number: 2, status: :continue, confidence: 0.8, reasoning: ""))

      expect(metrics.average_confidence).to be_within(0.01).of(0.7)
    end

    it "handles nil confidence gracefully" do
      metrics.track_evaluation(double(step_number: 1, status: :continue, confidence: nil, reasoning: ""))

      expect(metrics.average_confidence).to eq(0)
    end

    it "provides summary" do
      metrics.track_evaluation(double(step_number: 1, status: :continue, confidence: 0.8, reasoning: ""))
      metrics.track_refinement(double(iterations: 1, improved: true, confidence: 0.9))
      metrics.track_reflection(double(outcome: :success, reflection: "good"))
      metrics.track_step(double(step_number: 1, outcome: :success, observations: "done"))
      metrics.track_completion(double(outcome: :success, output: "result", steps_taken: 1))

      summary = metrics.summary

      expect(summary[:total_evaluations]).to eq(1)
      expect(summary[:total_refinements]).to eq(1)
      expect(summary[:total_reflections]).to eq(1)
      expect(summary[:total_steps]).to eq(1)
      expect(summary[:total_completions]).to eq(1)
      expect(summary[:improvement_rate]).to eq(100.0)
      expect(summary[:average_confidence]).to eq(80.0)
    end
  end

  describe ".build_improving_agent" do
    it "builds agent with evaluation and refinement" do
      execution_model = mock_model { |m| m.queue_final_answer("done") }

      result = Experiments::SelfImprovingAgent.build_improving_agent(
        execution_model:
      )

      expect(result[:agent]).to be_a(Smolagents::Agents::Agent)
      expect(result[:knowledge_base]).to be_a(Experiments::SelfImprovingAgent::KnowledgeBase)
      expect(result[:metrics]).to be_a(Experiments::SelfImprovingAgent::ImprovementMetrics)
    end

    it "accepts custom evaluation model" do
      execution_model = mock_model { |m| m.queue_final_answer("done") }
      evaluation_model = mock_model { |m| m.queue_final_answer("evaluated") }

      result = Experiments::SelfImprovingAgent.build_improving_agent(
        execution_model:,
        evaluation_model:
      )

      expect(result[:agent]).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "LearningAgent" do
    it "wraps agent with knowledge injection" do
      execution_model = mock_model { |m| m.queue_final_answer("done") }
      result = Experiments::SelfImprovingAgent.build_improving_agent(
        execution_model:
      )

      agent = Experiments::SelfImprovingAgent::LearningAgent.new(
        agent: result[:agent],
        knowledge_base: result[:knowledge_base],
        metrics: result[:metrics]
      )

      # Should respond to run and summary methods
      expect(agent).to respond_to(:run)
      expect(agent).to respond_to(:knowledge_summary)
      expect(agent).to respond_to(:improvement_summary)
    end
  end

  describe ".build_for_testing" do
    it "creates test setup with mock models" do
      result = Experiments::SelfImprovingAgent.build_for_testing(
        execution_responses: ["<code>\nfinal_answer(answer: \"done\")\n</code>"]
      )

      expect(result[:agent]).to respond_to(:run)
      expect(result[:raw_agent]).to be_a(Smolagents::Agents::Agent)
      expect(result[:models][:execution]).to be_a(Smolagents::Testing::MockModel)
    end

    it "accepts initial learnings" do
      initial = [
        Experiments::SelfImprovingAgent::Learning.from_reflection(
          task_type: "test",
          outcome: :success,
          reflection: "Prior knowledge"
        )
      ]

      result = Experiments::SelfImprovingAgent.build_for_testing(
        execution_responses: ["<code>\nfinal_answer(answer: \"done\")\n</code>"],
        initial_learnings: initial
      )

      expect(result[:knowledge_base].learnings.size).to eq(1)
    end
  end

  describe "agent execution with mocks" do
    it "completes task and can access summaries", :slow do
      result = Experiments::SelfImprovingAgent.build_for_testing(
        execution_responses: ["<code>\nfinal_answer(answer: \"42\")\n</code>"]
      )

      run_result = result[:agent].run("What is the answer?")

      expect(run_result.output).to eq("42")
      expect(result[:agent].knowledge_summary).to be_a(Hash)
      expect(result[:agent].improvement_summary).to be_a(Hash)
    end

    it "injects prior learnings into task" do
      initial = [
        Experiments::SelfImprovingAgent::Learning.from_reflection(
          task_type: "math",
          outcome: :success,
          reflection: "Show your work step by step"
        )
      ]

      result = Experiments::SelfImprovingAgent.build_for_testing(
        execution_responses: ["<code>\nfinal_answer(answer: \"done\")\n</code>"],
        initial_learnings: initial
      )

      result[:agent].run("Solve this math problem")

      # Check that the execution model received enhanced task
      last_call = result[:models][:execution].calls.last
      task_content = last_call.messages.find { |m| m.role == :user }&.content

      expect(task_content).to include("PRIOR LEARNINGS") if task_content
    end
  end

  describe "event emission during self-improvement" do
    it "tracks step_complete events via metrics collector", :slow do
      result = Experiments::SelfImprovingAgent.build_for_testing(
        execution_responses: ["<code>\nfinal_answer(answer: \"42\")\n</code>"]
      )

      result[:agent].run("Simple task")
      Smolagents::Events::AsyncQueue.drain(timeout: 2)

      # Verify step events were tracked
      expect(result[:metrics].steps).not_to be_empty
      expect(result[:metrics].steps.first).to have_key(:step_number)
      expect(result[:metrics].steps.first).to have_key(:outcome)
    end

    it "tracks task_complete events via metrics collector", :slow do
      result = Experiments::SelfImprovingAgent.build_for_testing(
        execution_responses: ["<code>\nfinal_answer(answer: \"done\")\n</code>"]
      )

      result[:agent].run("Complete this task")
      Smolagents::Events::AsyncQueue.drain(timeout: 2)

      # Verify completion events were tracked
      expect(result[:metrics].completions).not_to be_empty
      expect(result[:metrics].completions.first[:outcome]).to eq(:success)
      expect(result[:metrics].completions.first[:output]).to eq("done")
    end

    it "includes step and completion counts in summary", :slow do
      result = Experiments::SelfImprovingAgent.build_for_testing(
        execution_responses: ["<code>\nfinal_answer(answer: \"result\")\n</code>"]
      )

      result[:agent].run("Track everything")
      Smolagents::Events::AsyncQueue.drain(timeout: 2)

      summary = result[:metrics].summary
      expect(summary).to have_key(:total_steps)
      expect(summary).to have_key(:total_completions)
      expect(summary[:total_steps]).to be >= 1
      expect(summary[:total_completions]).to eq(1)
    end
  end
end
