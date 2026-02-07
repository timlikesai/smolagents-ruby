require "spec_helper"

RSpec.describe Smolagents::Events::GoalLifecycle do
  let(:tracker_class) do
    Class.new do
      include Smolagents::Concerns::GoalTracking
      include Smolagents::Events::Consumer

      def initialize = initialize_goal_tracking
    end
  end

  let(:tracker) { tracker_class.new }

  before do
    Smolagents::Events::CreateFactory.reset_sequence!
  end

  describe "GoalLifecycle (phase: :created) event" do
    it "is emitted when creating a root goal" do
      received = []
      tracker.on(:goal_lifecycle) { |e| received << e if e.created? }

      tracker.create_goal_from_task("Find Ruby docs")

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.size).to eq(1)
      expect(received.first).to be_a(described_class)
      expect(received.first.goal).to eq("Find Ruby docs")
      expect(received.first.parent_id).to be_nil
    end

    it "is emitted when creating a subgoal with parent_id" do
      received = []
      tracker.on(:goal_lifecycle) { |e| received << e if e.created? }

      root = tracker.create_goal_from_task("Main task")
      tracker.create_subgoal("Search web", parent: root)

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.size).to eq(2)

      root_event = received.first
      expect(root_event.goal).to eq("Main task")
      expect(root_event.parent_id).to be_nil

      subgoal_event = received.last
      expect(subgoal_event.goal).to eq("Search web")
      expect(subgoal_event.parent_id).to eq(root.id)
    end

    it "captures parent_id from current goal when parent not specified" do
      received = []
      tracker.on(:goal_lifecycle) { |e| received << e if e.created? }

      tracker.create_goal_from_task("Main task")
      tracker.create_subgoal("Implicit parent subgoal")

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      subgoal_event = received.last
      expect(subgoal_event.parent_id).not_to be_nil
    end
  end

  describe "GoalLifecycle (phase: :progress) event" do
    it "is emitted when updating goal progress" do
      received = []
      tracker.on(:goal_lifecycle) { |e| received << e if e.progress? }

      goal = tracker.create_goal_from_task("Find Ruby docs")
      tracker.update_goal_progress(goal, "Found 3 sources")

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.size).to eq(1)
      expect(received.first).to be_a(described_class)
      expect(received.first.goal).to eq("Find Ruby docs")
      expect(received.first.previous_progress).to be_nil
    end

    it "captures previous progress when updating" do
      received = []
      tracker.on(:goal_lifecycle) { |e| received << e if e.progress? }

      goal = tracker.create_goal_from_task("Find Ruby docs")
      tracker.update_goal_progress(goal, "Started searching")
      tracker.update_goal_progress(goal.id, "Found 3 sources")

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.size).to eq(2)

      first_update = received.first
      expect(first_update.previous_progress).to be_nil

      second_update = received.last
      expect(second_update.previous_progress).to eq("Started searching")
    end

    it "accepts goal ID string instead of goal object" do
      received = []
      tracker.on(:goal_lifecycle) { |e| received << e if e.progress? }

      goal = tracker.create_goal_from_task("Find Ruby docs")
      tracker.update_goal_progress(goal.id, "Progress update")

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.first.goal).to eq("Find Ruby docs")
    end
  end

  describe "event mappings" do
    it "maps :goal_lifecycle to GoalLifecycle" do
      event_class = Smolagents::Events::Mappings.resolve(:goal_lifecycle)
      expect(event_class).to eq(described_class)
    end
  end
end
