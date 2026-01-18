RSpec.describe Smolagents::Events::PlanDivergence do
  describe ".create" do
    it "creates event with required fields" do
      event = described_class.create(
        level: :moderate,
        task_relevance: 0.65,
        off_topic_count: 2
      )

      expect(event.level).to eq(:moderate)
      expect(event.task_relevance).to eq(0.65)
      expect(event.off_topic_count).to eq(2)
    end

    it "includes id and created_at" do
      event = described_class.create(
        level: :mild,
        task_relevance: 0.8,
        off_topic_count: 1
      )

      expect(event.id).to be_a(String)
      expect(event.created_at).to be_a(Time)
    end
  end

  describe "predicates" do
    it "responds to mild?" do
      event = described_class.create(level: :mild, task_relevance: 0.8, off_topic_count: 1)
      expect(event.mild?).to be true
      expect(event.moderate?).to be false
      expect(event.severe?).to be false
    end

    it "responds to moderate?" do
      event = described_class.create(level: :moderate, task_relevance: 0.5, off_topic_count: 3)
      expect(event.mild?).to be false
      expect(event.moderate?).to be true
      expect(event.severe?).to be false
    end

    it "responds to severe?" do
      event = described_class.create(level: :severe, task_relevance: 0.2, off_topic_count: 5)
      expect(event.mild?).to be false
      expect(event.moderate?).to be false
      expect(event.severe?).to be true
    end
  end
end
