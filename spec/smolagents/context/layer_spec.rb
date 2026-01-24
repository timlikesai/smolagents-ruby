require "spec_helper"
require "smolagents/context/layer"

RSpec.describe Smolagents::Context::Layer do
  describe "constants" do
    it "defines SYSTEM layer" do
      expect(described_class::SYSTEM).to have_attributes(
        id: 0, name: :system, priority: 100, survives_truncation: true
      )
    end

    it "defines PERSISTENT layer" do
      expect(described_class::PERSISTENT).to have_attributes(
        id: 1, name: :persistent, priority: 90, survives_truncation: true
      )
    end

    it "defines STRATEGIC layer" do
      expect(described_class::STRATEGIC).to have_attributes(
        id: 2, name: :strategic, priority: 80, survives_truncation: false
      )
    end

    it "defines TACTICAL layer" do
      expect(described_class::TACTICAL).to have_attributes(
        id: 3, name: :tactical, priority: 70, survives_truncation: false
      )
    end

    it "defines HISTORY layer" do
      expect(described_class::HISTORY).to have_attributes(
        id: 4, name: :history, priority: 50, survives_truncation: false
      )
    end

    it "defines TASK layer" do
      expect(described_class::TASK).to have_attributes(
        id: 5, name: :task, priority: 100, survives_truncation: true
      )
    end

    it "defines ALL as frozen array" do
      expect(described_class::ALL).to be_frozen
      expect(described_class::ALL.size).to eq(6)
    end
  end

  describe ".[]" do
    it "looks up layer by name" do
      expect(described_class[:system]).to eq(described_class::SYSTEM)
      expect(described_class[:persistent]).to eq(described_class::PERSISTENT)
      expect(described_class[:strategic]).to eq(described_class::STRATEGIC)
      expect(described_class[:tactical]).to eq(described_class::TACTICAL)
      expect(described_class[:history]).to eq(described_class::HISTORY)
      expect(described_class[:task]).to eq(described_class::TASK)
    end

    it "returns nil for unknown layer" do
      expect(described_class[:unknown]).to be_nil
    end
  end

  describe ".by_priority" do
    it "returns layers sorted by descending priority" do
      sorted = described_class.by_priority
      priorities = sorted.map(&:priority)
      expect(priorities).to eq(priorities.sort.reverse)
    end

    it "places SYSTEM and TASK first (highest priority)" do
      sorted = described_class.by_priority
      expect(sorted.first(2).map(&:name)).to contain_exactly(:system, :task)
    end

    it "places HISTORY last (lowest priority)" do
      sorted = described_class.by_priority
      expect(sorted.last.name).to eq(:history)
    end
  end

  describe ".truncatable" do
    it "returns layers that can be truncated" do
      truncatable = described_class.truncatable
      expect(truncatable.map(&:name)).to contain_exactly(:strategic, :tactical, :history)
    end

    it "excludes layers that survive truncation" do
      truncatable = described_class.truncatable
      expect(truncatable.none?(&:survives_truncation)).to be true
    end
  end

  describe "immutability" do
    it "is a Data.define value object" do
      expect(described_class::SYSTEM).to be_frozen
    end

    it "does not allow modification" do
      expect { described_class::SYSTEM.instance_variable_set(:@name, :hacked) }
        .to raise_error(FrozenError)
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys for hash patterns" do
      layer = described_class::SYSTEM
      keys = layer.deconstruct_keys(%i[name priority])
      expect(keys).to eq({ name: :system, priority: 100 })
    end

    it "supports deconstruct for array patterns" do
      layer = described_class::SYSTEM
      values = layer.deconstruct
      expect(values).to eq([0, :system, 100, true])
    end

    it "can be used in case/in with hash pattern" do
      layer = described_class::SYSTEM
      result = case layer
               in { survives_truncation: true } then :survives
               else :truncatable
               end
      expect(result).to eq(:survives)
    end

    it "can be used in case/in for truncatable layers" do
      layer = described_class::HISTORY
      result = case layer
               in { survives_truncation: false } then :truncatable
               else :survives
               end
      expect(result).to eq(:truncatable)
    end

    it "can match on specific attribute values" do
      layer = described_class::HISTORY
      result = case layer
               in { priority: 50 } then :low
               else :other
               end
      expect(result).to eq(:low)
    end
  end

  describe "ordering" do
    it "layers have unique ids" do
      ids = described_class::ALL.map(&:id)
      expect(ids).to eq(ids.uniq)
    end

    it "layers have unique names" do
      names = described_class::ALL.map(&:name)
      expect(names).to eq(names.uniq)
    end

    it "ids are sequential from 0" do
      ids = described_class::ALL.map(&:id).sort
      expect(ids).to eq((0..5).to_a)
    end
  end

  describe "equality" do
    it "layers with same attributes are equal" do
      layer1 = described_class.new(id: 99, name: :test, priority: 50, survives_truncation: true)
      layer2 = described_class.new(id: 99, name: :test, priority: 50, survives_truncation: true)
      expect(layer1).to eq(layer2)
    end

    it "layers with different attributes are not equal" do
      layer1 = described_class::SYSTEM
      layer2 = described_class::TASK
      expect(layer1).not_to eq(layer2)
    end
  end
end
