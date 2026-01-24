require "spec_helper"

RSpec.describe Smolagents::Concerns::GoalTracking do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::GoalTracking

      def initialize(goal_config: nil)
        initialize_goal_tracking(goal_config:)
      end
    end
  end

  let(:agent) { test_class.new }
  let(:agent_with_config) { test_class.new(goal_config: Smolagents::Types::GoalConfig.new) }

  describe "#initialize_goal_tracking" do
    it "creates a goal store" do
      expect(agent.goal_store).to be_a(Smolagents::Concerns::GoalTracking::Store)
    end

    it "accepts goal config" do
      config = Smolagents::Types::GoalConfig.new(visible: true)
      a = test_class.new(goal_config: config)
      expect(a.goal_config).to eq(config)
    end
  end

  describe "#current_goal" do
    it "returns nil when no goals" do
      expect(agent.current_goal).to be_nil
    end

    it "returns the active root goal" do
      goal = agent.create_goal_from_task("Find docs")
      expect(agent.current_goal).to eq(goal)
    end

    it "returns nil after goal is completed" do
      goal = agent.create_goal_from_task("Find docs")
      agent.complete_goal(goal, evidence: "Done")
      expect(agent.current_goal).to be_nil
    end
  end

  describe "#create_goal_from_task" do
    it "creates a root goal from task" do
      goal = agent.create_goal_from_task("Find Ruby 4.0 docs")

      expect(goal.description).to eq("Find Ruby 4.0 docs")
      expect(goal.active?).to be true
      expect(goal.root?).to be true
    end

    it "adds goal to store" do
      goal = agent.create_goal_from_task("Find docs")
      expect(agent.goal_store.get(goal.id)).to eq(goal)
    end

    it "supports multiple sequential tasks" do
      goal1 = agent.create_goal_from_task("Task 1")
      agent.complete_goal(goal1, evidence: "Done")

      goal2 = agent.create_goal_from_task("Task 2")
      expect(agent.current_goal).to eq(goal2)
      expect(agent.goal_store.size).to eq(2)
    end
  end

  describe "#create_subgoal" do
    it "creates subgoal under current goal" do
      parent = agent.create_goal_from_task("Main task")
      subgoal = agent.create_subgoal("Subtask")

      expect(subgoal.parent_id).to eq(parent.id)
      expect(subgoal.root?).to be false
    end

    it "accepts explicit parent" do
      parent = agent.create_goal_from_task("Main task")
      agent.create_goal_from_task("Other task") # Creates another root, making parent not current
      subgoal = agent.create_subgoal("Subtask", parent:)

      expect(subgoal.parent_id).to eq(parent.id)
    end

    it "raises when no parent available" do
      expect { agent.create_subgoal("Orphan") }.to raise_error(ArgumentError, /No parent goal/)
    end

    it "allows nested subgoals" do
      root = agent.create_goal_from_task("Root")
      child = agent.create_subgoal("Child")
      grandchild = agent.create_subgoal("Grandchild", parent: child)

      expect(grandchild.parent_id).to eq(child.id)
      expect(child.parent_id).to eq(root.id)
    end
  end

  describe "#complete_goal" do
    it "completes goal with evidence" do
      goal = agent.create_goal_from_task("Find docs")
      completed = agent.complete_goal(goal, evidence: "Found 3 sources")

      expect(completed.completed?).to be true
      expect(completed.progress).to eq("Found 3 sources")
    end

    it "accepts goal ID string" do
      goal = agent.create_goal_from_task("Find docs")
      completed = agent.complete_goal(goal.id, evidence: "Done")

      expect(completed.completed?).to be true
    end

    it "preserves goal in store after completion" do
      goal = agent.create_goal_from_task("Find docs")
      agent.complete_goal(goal, evidence: "Done")

      expect(agent.goal_store.size).to eq(1)
      expect(agent.goal_store.completed.size).to eq(1)
    end
  end

  describe "#update_goal_progress" do
    it "updates goal progress" do
      goal = agent.create_goal_from_task("Find docs")
      updated = agent.update_goal_progress(goal, "Found 2 sources")

      expect(updated.progress).to eq("Found 2 sources")
      expect(updated.active?).to be true
    end

    it "accepts goal ID string" do
      goal = agent.create_goal_from_task("Find docs")
      updated = agent.update_goal_progress(goal.id, "Progress")

      expect(updated.progress).to eq("Progress")
    end
  end

  describe "#goal_tracking_enabled?" do
    it "returns true by default (nil config)" do
      expect(agent.goal_tracking_enabled?).to be true
    end

    it "returns true when config enabled" do
      expect(agent_with_config.goal_tracking_enabled?).to be true
    end

    it "returns false when config disabled" do
      config = Smolagents::Types::GoalConfig.disabled
      a = test_class.new(goal_config: config)
      expect(a.goal_tracking_enabled?).to be false
    end
  end

  describe "#build_goal_context" do
    it "returns nil when no current goal" do
      expect(agent.build_goal_context).to be_nil
    end

    it "returns formatted context for current goal" do
      agent.create_goal_from_task("Find Ruby 4.0 docs")
      context = agent.build_goal_context

      expect(context).to include("Current goal: Find Ruby 4.0 docs")
    end

    it "includes progress when present" do
      goal = agent.create_goal_from_task("Find docs")
      agent.update_goal_progress(goal, "Searching...")
      context = agent.build_goal_context

      expect(context).to include("Progress: Searching...")
    end

    it "includes completed goals summary" do
      goal1 = agent.create_goal_from_task("Task 1")
      agent.complete_goal(goal1, evidence: "Done")

      agent.create_goal_from_task("Task 2")
      context = agent.build_goal_context

      expect(context).to include("Completed: 1 goal(s)")
    end

    it "returns nil when goal tracking disabled" do
      config = Smolagents::Types::GoalConfig.disabled
      a = test_class.new(goal_config: config)
      a.create_goal_from_task("Task")

      expect(a.build_goal_context).to be_nil
    end
  end

  describe "subagent isolation" do
    it "subagents have isolated goal stores" do
      parent_agent = test_class.new
      child_agent = test_class.new

      parent_agent.create_goal_from_task("Parent task")
      child_agent.create_goal_from_task("Child task")

      expect(parent_agent.goal_store.size).to eq(1)
      expect(child_agent.goal_store.size).to eq(1)
      expect(parent_agent.current_goal.description).to eq("Parent task")
      expect(child_agent.current_goal.description).to eq("Child task")
    end
  end
end
