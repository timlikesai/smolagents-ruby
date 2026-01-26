RSpec.describe Smolagents::Types::ResultFormatConfig do
  describe ".default" do
    it "creates config with default field mappings" do
      config = described_class.default

      expect(config.title).to eq(:title)
      expect(config.link).to eq(:link)
      expect(config.description).to eq(:description)
    end

    it "creates config with indexing disabled" do
      config = described_class.default

      expect(config.indexed).to be false
    end

    it "creates config with default header" do
      config = described_class.default

      expect(config.header).to eq("## Search Results")
    end

    it "creates config with nil metadata fields" do
      config = described_class.default

      expect(config.snippet).to be_nil
      expect(config.date).to be_nil
    end

    it "is frozen" do
      config = described_class.default

      expect(config).to be_frozen
    end
  end

  describe ".create" do
    it "creates config with custom field mappings" do
      config = described_class.create(
        title: :name,
        link: :url,
        description: :summary
      )

      expect(config.title).to eq(:name)
      expect(config.link).to eq(:url)
      expect(config.description).to eq(:summary)
    end

    it "creates config with indexing enabled" do
      config = described_class.create(indexed: true)

      expect(config.indexed).to be true
    end

    it "creates config with custom header" do
      config = described_class.create(header: "## Results")

      expect(config.header).to eq("## Results")
    end

    it "creates config with metadata fields" do
      config = described_class.create(
        snippet: :excerpt,
        date: :published_at
      )

      expect(config.snippet).to eq(:excerpt)
      expect(config.date).to eq(:published_at)
    end

    it "is frozen" do
      config = described_class.create(title: :name)

      expect(config).to be_frozen
    end
  end

  describe ".with_metadata" do
    it "creates config for metadata-rich results" do
      config = described_class.with_metadata(
        title: "headline",
        link: "url",
        snippet: "excerpt",
        date: "published_at"
      )

      expect(config.title).to eq("headline")
      expect(config.link).to eq("url")
      expect(config.snippet).to eq("excerpt")
      expect(config.date).to eq("published_at")
    end

    it "enables indexing by default" do
      config = described_class.with_metadata

      expect(config.indexed).to be true
    end

    it "sets description to nil" do
      config = described_class.with_metadata

      expect(config.description).to be_nil
    end

    it "is frozen" do
      config = described_class.with_metadata

      expect(config).to be_frozen
    end
  end

  describe "#with" do
    it "returns new config with changes" do
      config = described_class.default
      updated = config.with(indexed: true, header: "## Custom")

      expect(updated.indexed).to be true
      expect(updated.header).to eq("## Custom")
      expect(updated.title).to eq(:title) # unchanged
    end

    it "does not modify original config" do
      config = described_class.default
      _ = config.with(indexed: true)

      expect(config.indexed).to be false
    end

    it "returns frozen instance" do
      config = described_class.default
      updated = config.with(title: :name)

      expect(updated).to be_frozen
    end
  end

  describe "#indexed?" do
    it "returns true when indexed is true" do
      config = described_class.create(indexed: true)

      expect(config.indexed?).to be true
    end

    it "returns false when indexed is false" do
      config = described_class.default

      expect(config.indexed?).to be false
    end
  end

  describe "#metadata_format?" do
    it "returns true when snippet is set" do
      config = described_class.create(snippet: :excerpt)

      expect(config.metadata_format?).to be true
    end

    it "returns true when date is set" do
      config = described_class.create(date: :published_at)

      expect(config.metadata_format?).to be true
    end

    it "returns false when both snippet and date are nil" do
      config = described_class.default

      expect(config.metadata_format?).to be false
    end
  end

  describe "#field_keys" do
    it "returns hash with title, link, and description" do
      config = described_class.create(
        title: :name,
        link: :url,
        description: :summary
      )

      expect(config.field_keys).to eq({
                                        title: :name,
                                        link: :url,
                                        description: :summary
                                      })
    end

    it "includes nil description when not set" do
      config = described_class.with_metadata

      expect(config.field_keys[:description]).to be_nil
    end
  end

  describe "pattern matching" do
    it "matches on indexed" do
      config = described_class.create(indexed: true)

      matched = case config
                in indexed: true
                  "numbered"
                else
                  "not numbered"
                end

      expect(matched).to eq("numbered")
    end

    it "matches on title field" do
      config = described_class.create(title: :headline)

      matched = case config
                in title: :headline
                  "headline"
                else
                  "other"
                end

      expect(matched).to eq("headline")
    end
  end

  describe "immutability" do
    it "creates frozen instances" do
      config = described_class.default

      expect(config).to be_frozen
    end

    it "with method returns new frozen instance" do
      config = described_class.default
      updated = config.with(indexed: true)

      expect(updated).to be_frozen
      expect(config.indexed).to be false
    end
  end
end
