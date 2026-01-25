RSpec.describe Smolagents::ToolResult do
  describe "Core functionality" do
    describe "initialization" do
      it "creates a ToolResult with data" do
        result = described_class.new([1, 2, 3], tool_name: "test_tool")

        expect(result.data).to eq([1, 2, 3])
        expect(result.tool_name).to eq("test_tool")
      end

      it "converts tool_name to string" do
        result = described_class.new(42, tool_name: :numeric_tool)

        expect(result.tool_name).to be_a(String)
        expect(result.tool_name).to eq("numeric_tool")
      end

      it "creates metadata with created_at timestamp" do
        result = described_class.new("data", tool_name: "test")

        expect(result.metadata).to have_key(:created_at)
        expect(result.metadata[:created_at]).to be_a(Time)
      end

      it "merges user-provided metadata" do
        metadata = { source: "api", version: 1 }
        result = described_class.new("data", tool_name: "test", metadata:)

        expect(result.metadata).to include(source: "api", version: 1)
        expect(result.metadata).to have_key(:created_at)
      end

      it "freezes data to ensure immutability" do
        array_data = [1, 2, 3]
        result = described_class.new(array_data, tool_name: "test")

        expect(result.data).to be_frozen
      end

      it "deep freezes nested structures" do
        nested_data = { items: [{ name: "Alice" }, { name: "Bob" }] }
        result = described_class.new(nested_data, tool_name: "test")

        expect(result.data).to be_frozen
        expect(result.data[:items]).to be_frozen
        expect(result.data[:items][0]).to be_frozen
      end

      it "freezes metadata" do
        result = described_class.new("data", tool_name: "test", metadata: { key: "value" })

        expect(result.metadata).to be_frozen
      end
    end

    describe "data access" do
      it "provides access to wrapped data" do
        data = { key: "value" }
        result = described_class.new(data, tool_name: "test")

        expect(result.data).to eq(data)
      end

      it "handles nil data" do
        result = described_class.new(nil, tool_name: "test")

        expect(result.data).to be_nil
      end

      it "handles empty collections" do
        result_array = described_class.new([], tool_name: "test")
        result_hash = described_class.new({}, tool_name: "test")

        expect(result_array.data).to be_empty
        expect(result_hash.data).to be_empty
      end

      it "handles scalar values" do
        result_string = described_class.new("hello", tool_name: "test")
        result_number = described_class.new(42, tool_name: "test")
        result_boolean = described_class.new(true, tool_name: "test")

        expect(result_string.data).to eq("hello")
        expect(result_number.data).to eq(42)
        expect(result_boolean.data).to be(true)
      end
    end

    describe "#initialize with metadata tracking" do
      it "tracks successful operation" do
        result = described_class.new("output", tool_name: "test", metadata: { success: true })

        expect(result.metadata[:success]).to be(true)
      end

      it "tracks errors in metadata" do
        result = described_class.new(nil, tool_name: "test", metadata: { error: "Connection failed" })

        expect(result.metadata[:error]).to eq("Connection failed")
      end

      it "preserves metadata through initialization" do
        original_metadata = { custom_field: "custom_value", nested: { key: "val" } }
        result = described_class.new("data", tool_name: "test", metadata: original_metadata)

        expect(result.metadata).to include(custom_field: "custom_value")
        expect(result.metadata[:nested]).to eq({ key: "val" })
      end
    end

    describe "immutability constraints" do
      it "prevents modification of data" do
        result = described_class.new([1, 2, 3], tool_name: "test")

        expect { result.data << 4 }.to raise_error(FrozenError)
      end

      it "prevents modification of metadata" do
        result = described_class.new("data", tool_name: "test")

        expect { result.metadata[:custom] = "value" }.to raise_error(FrozenError)
      end

      it "prevents modification of nested data" do
        result = described_class.new({ items: [1, 2, 3] }, tool_name: "test")

        expect { result.data[:items] << 4 }.to raise_error(FrozenError)
      end
    end

    describe "special data types" do
      it "handles complex nested structures" do
        complex_data = {
          users: [
            { id: 1, name: "Alice", tags: %w[admin user] },
            { id: 2, name: "Bob", tags: %w[user] }
          ],
          metadata: { total: 2, page: 1 }
        }
        result = described_class.new(complex_data, tool_name: "test")

        expect(result.data[:users][0][:name]).to eq("Alice")
        expect(result.data[:users][0][:tags][0]).to eq("admin")
        expect(result.data[:metadata][:page]).to eq(1)
      end

      it "handles time objects" do
        time = Time.now
        result = described_class.new(time, tool_name: "test")

        expect(result.data).to be_a(Time)
      end

      it "handles symbol keys" do
        data = { symbol_key: "value", another: 42 }
        result = described_class.new(data, tool_name: "test")

        expect(result.data[:symbol_key]).to eq("value")
      end
    end

    describe "tool_name handling" do
      it "converts symbol tool_name to string" do
        result = described_class.new("data", tool_name: :my_tool)

        expect(result.tool_name).to be_a(String)
        expect(result.tool_name).to eq("my_tool")
      end

      it "freezes tool_name" do
        result = described_class.new("data", tool_name: "test")

        expect(result.tool_name).to be_frozen
      end

      it "preserves tool_name case" do
        result = described_class.new("data", tool_name: "MyTool")

        expect(result.tool_name).to eq("MyTool")
      end
    end
  end
end
