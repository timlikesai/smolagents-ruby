require "spec_helper"

RSpec.describe Smolagents::Types::CachedPlan do
  describe ".create" do
    it "creates a cached plan with generated UUID" do
      cached = described_class.create(
        task: "Find Ruby release notes",
        plan: "1. Search for Ruby\n2. Parse results"
      )

      expect(cached.plan_id).to match(/\A[0-9a-f-]{36}\z/)
      expect(cached.plan_content).to eq("1. Search for Ruby\n2. Parse results")
      expect(cached.reuse_count).to eq(0)
    end

    it "normalizes task to lowercase pattern" do
      cached = described_class.create(
        task: "Find Ruby Release Notes",
        plan: "1. Search"
      )

      expect(cached.task_pattern).to eq("find ruby release notes")
    end

    it "freezes tool_names array" do
      cached = described_class.create(
        task: "Search",
        plan: "1. Search",
        tools: ["search", "web"]
      )

      expect(cached.tool_names).to eq(["search", "web"])
      expect(cached.tool_names).to be_frozen
    end

    it "counts numbered steps in plan" do
      cached = described_class.create(
        task: "Research",
        plan: "1. First step\n2. Second step\n3. Third step"
      )

      expect(cached.step_count).to eq(3)
    end

    it "sets created_at and last_used_at to current time" do
      freeze_time = Time.now
      allow(Time).to receive(:now).and_return(freeze_time)

      cached = described_class.create(task: "Test", plan: "1. Do")

      expect(cached.created_at).to eq(freeze_time)
      expect(cached.last_used_at).to eq(freeze_time)
    end
  end

  describe ".normalize_task" do
    it "lowercases the task" do
      expect(described_class.normalize_task("FIND RUBY")).to eq("find ruby")
    end

    it "normalizes multiple spaces to single space" do
      expect(described_class.normalize_task("find   ruby")).to eq("find ruby")
    end

    it "strips leading and trailing whitespace" do
      expect(described_class.normalize_task("  find ruby  ")).to eq("find ruby")
    end

    it "handles nil gracefully" do
      expect(described_class.normalize_task(nil)).to eq("")
    end

    it "handles newlines and tabs" do
      expect(described_class.normalize_task("find\nruby\tinfo")).to eq("find ruby info")
    end
  end

  describe ".count_steps" do
    it "counts steps starting with numbers followed by period" do
      plan = "1. First\n2. Second\n3. Third"
      expect(described_class.count_steps(plan)).to eq(3)
    end

    it "returns 0 for plan without numbered steps" do
      plan = "- First\n- Second"
      expect(described_class.count_steps(plan)).to eq(0)
    end

    it "handles nil plan" do
      expect(described_class.count_steps(nil)).to eq(0)
    end

    it "only counts steps at line start" do
      plan = "Step 1. is here\n2. Real step"
      expect(described_class.count_steps(plan)).to eq(1)
    end

    it "handles multi-digit step numbers" do
      plan = "1. First\n10. Tenth\n100. Hundredth"
      expect(described_class.count_steps(plan)).to eq(3)
    end
  end

  describe "#mark_used" do
    it "returns new instance with incremented reuse_count" do
      original = described_class.create(task: "Test", plan: "1. Do")
      updated = original.mark_used

      expect(updated.reuse_count).to eq(1)
      expect(original.reuse_count).to eq(0)
    end

    it "updates last_used_at" do
      original = described_class.create(task: "Test", plan: "1. Do")
      later_time = Time.now + 60
      allow(Time).to receive(:now).and_return(later_time)

      updated = original.mark_used

      expect(updated.last_used_at).to eq(later_time)
      expect(original.last_used_at).not_to eq(later_time)
    end

    it "increments correctly on multiple calls" do
      cached = described_class.create(task: "Test", plan: "1. Do")
      cached = cached.mark_used
      cached = cached.mark_used
      cached = cached.mark_used

      expect(cached.reuse_count).to eq(3)
    end
  end

  describe "#age_seconds" do
    it "returns seconds since creation" do
      cached = described_class.create(task: "Test", plan: "1. Do")
      allow(Time).to receive(:now).and_return(cached.created_at + 100)

      expect(cached.age_seconds).to eq(100)
    end
  end

  describe "#stale?" do
    it "returns false when plan is younger than max age" do
      cached = described_class.create(task: "Test", plan: "1. Do")
      allow(Time).to receive(:now).and_return(cached.created_at + 1800)

      expect(cached.stale?(max_age_seconds: 3600)).to be false
    end

    it "returns true when plan exceeds max age" do
      cached = described_class.create(task: "Test", plan: "1. Do")
      allow(Time).to receive(:now).and_return(cached.created_at + 3700)

      expect(cached.stale?(max_age_seconds: 3600)).to be true
    end

    it "uses default max age of 3600 seconds" do
      cached = described_class.create(task: "Test", plan: "1. Do")
      allow(Time).to receive(:now).and_return(cached.created_at + 3500)

      expect(cached.stale?).to be false

      allow(Time).to receive(:now).and_return(cached.created_at + 3700)
      expect(cached.stale?).to be true
    end
  end

  describe "#to_h" do
    it "returns hash representation with ISO8601 timestamps" do
      freeze_time = Time.new(2025, 1, 15, 12, 0, 0, "+00:00")
      allow(Time).to receive(:now).and_return(freeze_time)

      cached = described_class.create(
        task: "Test",
        plan: "1. Do",
        tools: ["search"]
      )
      result = cached.to_h

      expect(result[:plan_id]).to match(/\A[0-9a-f-]{36}\z/)
      expect(result[:task_pattern]).to eq("test")
      expect(result[:plan_content]).to eq("1. Do")
      expect(result[:tool_names]).to eq(["search"])
      expect(result[:step_count]).to eq(1)
      expect(result[:created_at]).to eq(freeze_time.iso8601)
      expect(result[:last_used_at]).to eq(freeze_time.iso8601)
      expect(result[:reuse_count]).to eq(0)
    end
  end

  describe "immutability" do
    it "is immutable via Data.define" do
      cached = described_class.create(task: "Test", plan: "1. Do")

      expect { cached.plan_content = "Other" }.to raise_error(NoMethodError)
    end

    it "mark_used does not modify original" do
      original = described_class.create(task: "Test", plan: "1. Do")
      original.mark_used

      expect(original.reuse_count).to eq(0)
    end
  end
end
