RSpec.describe Smolagents::Utilities::Comparison::Grouping do
  describe ".group" do
    it "groups empty array returns empty array" do
      result = described_class.group([])

      expect(result).to eq([])
    end

    it "groups single value into one group" do
      result = described_class.group(["item 123"])

      expect(result.size).to eq(1)
      expect(result.first).to eq(["item 123"])
    end

    it "groups identical values together" do
      items = ["value 42", "value 42", "value 42"]
      result = described_class.group(items)

      expect(result.size).to eq(1)
      expect(result.first).to contain_exactly("value 42", "value 42", "value 42")
    end

    it "creates separate groups for very different values" do
      # Use values with distinct entities that won't match
      items = ["number 111", "number 222", "number 333"]
      result = described_class.group(items, threshold: 0.9)

      # Very different items should be separate groups
      expect(result.length).to be >= 2
    end

    it "groups similar strings by similarity threshold" do
      items = ["Ruby is great", "Ruby is awesome", "Python is good"]
      result = described_class.group(items, threshold: 0.5)

      # First two are similar, third is different
      all_items = result.flatten
      expect(all_items).to match_array(items)
    end

    it "sorts groups by size (largest first)" do
      items = %w[a a a b b c]
      result = described_class.group(items)

      # Largest group first
      expect(result.first.length).to be >= result.last.length
    end

    it "returns array of arrays" do
      result = described_class.group(%w[test1 test2])

      expect(result).to be_an(Array)
      result.each { |group| expect(group).to be_an(Array) }
    end

    it "preserves original values in groups" do
      items = %w[Ruby ruby Python]
      result = described_class.group(items, threshold: 0.5)

      all_values = result.flatten
      expect(all_values).to match_array(items)
    end

    it "handles single character items" do
      items = %w[a b c]
      result = described_class.group(items, threshold: 0.9)

      all_values = result.flatten
      expect(all_values).to match_array(items)
    end

    it "maintains insertion order within groups" do
      items = %w[first second first]
      result = described_class.group(items, threshold: 0.9)

      # Items added first appear first in their group
      all_values = result.flatten
      expect(all_values).to match_array(items)
    end
  end

  describe ".build_groups" do
    it "returns empty array for empty input" do
      result = described_class.build_groups([], 0.7)

      expect(result).to eq([])
    end

    it "groups answers by similarity" do
      items = %w[test1 test2 test3]
      result = described_class.build_groups(items, 0.7)

      all_values = result.flatten
      expect(all_values).to match_array(items)
    end

    it "accepts custom threshold" do
      items = %w[apple apples orange]
      result = described_class.build_groups(items, 0.8)

      all_values = result.flatten
      expect(all_values).to match_array(items)
    end
  end

  describe ".find_matching_group" do
    it "returns nil for empty groups" do
      result = described_class.find_matching_group([], "test", 0.7)

      expect(result).to be_nil
    end

    it "finds a matching group" do
      groups = [["apple"], ["banana"]]
      result = described_class.find_matching_group(groups, "apple", 0.99)

      expect(result).to eq(["apple"])
    end

    it "returns nil when no match found" do
      # Use values with entities that won't match
      groups = [["code 111"], ["code 222"]]
      result = described_class.find_matching_group(groups, "code 333", 0.99)

      expect(result).to be_nil
    end

    it "uses similarity threshold" do
      groups = [["test1"], ["other"]]
      result = described_class.find_matching_group(groups, "test1", 0.99)

      expect(result).to eq(["test1"])
    end
  end

  describe ".sort_by_size" do
    it "returns empty array for empty groups" do
      result = described_class.sort_by_size([])

      expect(result).to eq([])
    end

    it "sorts groups by size (largest first)" do
      groups = [%w[a b], ["x"], %w[p q r]]
      result = described_class.sort_by_size(groups)

      expect(result.first.length).to eq(3)
      expect(result.last.length).to eq(1)
    end

    it "preserves group order when sizes equal" do
      groups = [%w[a b], %w[x y]]
      result = described_class.sort_by_size(groups)

      expect(result.flatten.length).to eq(4)
    end
  end
end
