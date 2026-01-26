RSpec.describe Smolagents::ToolResult do
  describe "Utility methods" do
    describe "#to_s" do
      it "converts data to string" do
        result = described_class.new("hello", tool_name: "test")

        expect(result.to_s).to eq("hello")
      end

      it "handles array data" do
        result = described_class.new([1, 2, 3], tool_name: "test")
        string_rep = result.to_s

        # ToolResult formats arrays as markdown lists, not raw syntax
        expect(string_rep).to include("1")
        expect(string_rep).to include("2")
      end

      it "handles hash data" do
        result = described_class.new({ name: "Alice" }, tool_name: "test")
        string_rep = result.to_s

        expect(string_rep).to include("name")
      end

      it "handles nil data" do
        result = described_class.new(nil, tool_name: "test")

        expect(result.to_s).to eq("")
      end

      it "handles numeric data" do
        result = described_class.new(42, tool_name: "test")

        expect(result.to_s).to eq("42")
      end
    end

    describe "#inspect" do
      it "returns detailed representation" do
        result = described_class.new([1, 2], tool_name: "test")
        inspect_str = result.inspect

        expect(inspect_str).to include("ToolResult")
        expect(inspect_str).to include("test")
      end

      it "includes data in inspection" do
        result = described_class.new({ key: "value" }, tool_name: "test")

        expect(result.inspect).to include("key")
      end
    end

    describe "#==" do
      it "equals another ToolResult with same data and tool_name" do
        result1 = described_class.new([1, 2], tool_name: "test")
        result2 = described_class.new([1, 2], tool_name: "test")

        expect(result1).to eq(result2)
      end

      it "does not equal ToolResult with different data" do
        result1 = described_class.new([1, 2], tool_name: "test")
        result2 = described_class.new([1, 3], tool_name: "test")

        expect(result1).not_to eq(result2)
      end

      it "does not equal ToolResult with different tool_name" do
        result1 = described_class.new([1, 2], tool_name: "test1")
        result2 = described_class.new([1, 2], tool_name: "test2")

        expect(result1).not_to eq(result2)
      end

      it "equals the raw data" do
        result = described_class.new([1, 2, 3], tool_name: "test")

        expect(result == [1, 2, 3]).to be true
      end

      it "equals scalar values" do
        result = described_class.new(42, tool_name: "test")

        expect(result == 42).to be true
      end
    end

    describe "#hash" do
      it "provides consistent hash value" do
        result1 = described_class.new([1, 2], tool_name: "test")
        result2 = described_class.new([1, 2], tool_name: "test")

        expect(result1.hash).to eq(result2.hash)
      end

      it "works with hash as dictionary key" do
        result = described_class.new([1, 2], tool_name: "test")
        hash_map = { result => "value" }

        expect(hash_map[result]).to eq("value")
      end

      it "different data produces different hash" do
        result1 = described_class.new([1, 2], tool_name: "test")
        result2 = described_class.new([1, 3], tool_name: "test")

        expect(result1.hash).not_to eq(result2.hash)
      end
    end

    describe "#eql?" do
      it "returns true for same content and tool_name" do
        result1 = described_class.new([1, 2], tool_name: "test")
        result2 = described_class.new([1, 2], tool_name: "test")

        expect(result1.eql?(result2)).to be true
      end

      it "returns false for different data" do
        result1 = described_class.new([1, 2], tool_name: "test")
        result2 = described_class.new([1, 3], tool_name: "test")

        expect(result1.eql?(result2)).to be false
      end
    end

    describe "#dup" do
      it "creates a copy of the ToolResult" do
        original = described_class.new([1, 2, 3], tool_name: "test")
        copy = original.dup

        expect(copy).to eq(original)
        expect(copy).not_to be(original)
      end

      it "preserves data in duplicate" do
        original = described_class.new({ a: 1, b: 2 }, tool_name: "test")
        copy = original.dup

        expect(copy.data).to eq(original.data)
      end

      it "preserves tool_name in duplicate" do
        original = described_class.new([1, 2], tool_name: "my_tool")
        copy = original.dup

        expect(copy.tool_name).to eq("my_tool")
      end
    end

    describe "#clone" do
      it "creates a copy with same data" do
        original = described_class.new([1, 2], tool_name: "test")
        clone = original.clone

        expect(clone.data).to eq([1, 2])
        expect(clone.tool_name).to eq("test")
      end

      it "preserves all metadata" do
        metadata = { custom: "value" }
        original = described_class.new([1, 2], tool_name: "test", metadata:)
        clone = original.clone

        expect(clone.metadata[:custom]).to eq("value")
      end
    end

    describe "Comparable operators" do
      describe "#<, #>, #<=, #>=" do
        it "compares numeric results" do
          result1 = described_class.new(10, tool_name: "test")
          result2 = described_class.new(20, tool_name: "test")

          expect(result1 < result2).to be true
          expect(result2 > result1).to be true
          expect(result1 <= result2).to be true
          expect(result2 >= result1).to be true
        end

        it "compares equal numeric results" do
          result1 = described_class.new(10, tool_name: "test")
          result2 = described_class.new(10, tool_name: "test")

          expect(result1 <= result2).to be true
          expect(result1 >= result2).to be true
          expect(result1 == result2).to be true
        end

        it "returns nil for non-numeric comparison" do
          result1 = described_class.new("apple", tool_name: "test")
          result2 = described_class.new("banana", tool_name: "test")

          # <=> returns nil for non-numeric types, so comparison raises
          expect { result1 < result2 }.to raise_error(ArgumentError, /comparison/)
        end
      end

      describe "#between?" do
        it "checks if value is between bounds" do
          result = described_class.new(15, tool_name: "test")

          expect(result.between?(10, 20)).to be true
          expect(result.between?(16, 20)).to be false
        end
      end
    end

    describe "#freeze" do
      it "freezes the result" do
        result = described_class.new([1, 2], tool_name: "test")
        result.freeze

        expect(result).to be_frozen
      end
    end

    describe "#frozen?" do
      it "returns true if frozen" do
        result = described_class.new([1, 2], tool_name: "test")
        result.freeze

        expect(result.frozen?).to be true
      end

      it "returns false if not frozen" do
        result = described_class.new([1, 2], tool_name: "test")

        expect(result.frozen?).to be false
      end
    end

    describe "#class" do
      it "returns ToolResult class" do
        result = described_class.new(42, tool_name: "test")

        expect(result.class).to eq(described_class)
      end
    end

    describe "#kind_of? and #is_a?" do
      it "identifies as ToolResult" do
        result = described_class.new(42, tool_name: "test")

        expect(result.is_a?(described_class)).to be true
        expect(result.is_a?(described_class)).to be true
      end

      it "identifies as Enumerable" do
        result = described_class.new([1, 2], tool_name: "test")

        expect(result.is_a?(Enumerable)).to be true
      end
    end

    describe "String representation methods" do
      describe "#pretty_print" do
        it "provides readable output" do
          result = described_class.new([1, 2, 3], tool_name: "test")
          output = StringIO.new
          result.pretty_print(PP.new(output))

          expect(output.string).to include("test")
        end
      end
    end

    describe "#respond_to?" do
      it "responds to Enumerable methods" do
        result = described_class.new([1, 2], tool_name: "test")

        expect(result.respond_to?(:each)).to be true
        expect(result.respond_to?(:map)).to be true
        expect(result.respond_to?(:select)).to be true
      end

      it "responds to arithmetic operators" do
        result = described_class.new(10, tool_name: "test")

        expect(result.respond_to?(:+)).to be true
        expect(result.respond_to?(:-)).to be true
        expect(result.respond_to?(:*)).to be true
      end

      it "responds to data accessors" do
        result = described_class.new([1, 2], tool_name: "test")

        expect(result.respond_to?(:data)).to be true
        expect(result.respond_to?(:tool_name)).to be true
        expect(result.respond_to?(:metadata)).to be true
      end
    end

    describe "#object_id" do
      it "returns unique identifier" do
        result = described_class.new([1, 2], tool_name: "test")

        expect(result.object_id).to be_a(Integer)
      end

      it "differs for different instances" do
        result1 = described_class.new([1, 2], tool_name: "test")
        result2 = described_class.new([1, 2], tool_name: "test")

        expect(result1.object_id).not_to eq(result2.object_id)
      end
    end
  end
end
