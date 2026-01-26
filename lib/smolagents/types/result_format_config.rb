module Smolagents
  module Types
    # Configuration for formatting search results as markdown.
    #
    # Encapsulates field mapping and display options for rendering results.
    # Supports both simple format (title, link, description) and metadata
    # format (with snippet and date fields).
    #
    # @example Default configuration
    #   config = ResultFormatConfig.default
    #   config.title       # => :title
    #   config.indexed?    # => false
    #
    # @example Custom field mapping
    #   config = ResultFormatConfig.create(
    #     title: :name,
    #     link: :url,
    #     description: :summary,
    #     indexed: true
    #   )
    #
    # @example Metadata format configuration
    #   config = ResultFormatConfig.with_metadata(
    #     title: "headline",
    #     link: "url",
    #     snippet: "excerpt",
    #     date: "published_at"
    #   )
    #
    # @see Concerns::Results Uses this for result formatting
    ResultFormatConfig = Data.define(
      :title,
      :link,
      :description,
      :indexed,
      :header,
      :snippet,
      :date
    ) do
      # Creates a default configuration for simple result formatting.
      #
      # @return [ResultFormatConfig] Config with default field mappings
      def self.default
        new(
          title: :title,
          link: :link,
          description: :description,
          indexed: false,
          header: "## Search Results",
          snippet: nil,
          date: nil
        )
      end

      # Creates a configuration with specified options.
      #
      # @param title [Symbol, String] Key for title field
      # @param link [Symbol, String] Key for link field
      # @param description [Symbol, String, nil] Key for description field
      # @param indexed [Boolean] Whether to number results
      # @param header [String] Header text for output
      # @param snippet [String, nil] Key for snippet field (metadata mode)
      # @param date [String, nil] Key for date field (metadata mode)
      # @return [ResultFormatConfig]
      def self.create(
        title: :title,
        link: :link,
        description: :description,
        indexed: false,
        header: "## Search Results",
        snippet: nil,
        date: nil
      )
        new(title:, link:, description:, indexed:, header:, snippet:, date:)
      end

      # Creates a configuration for metadata-rich result formatting.
      #
      # @param title [String] Key for title field
      # @param link [String] Key for link field
      # @param snippet [String] Key for snippet/excerpt field
      # @param date [String] Key for date field
      # @return [ResultFormatConfig]
      def self.with_metadata(title: "title", link: "link", snippet: "snippet", date: "date")
        new(
          title:,
          link:,
          description: nil,
          indexed: true,
          header: "## Search Results",
          snippet:,
          date:
        )
      end

      # Returns a new config with the specified changes.
      #
      # @param options [Hash] Fields to change
      # @return [ResultFormatConfig] New config with changes applied
      def with(**)
        self.class.new(**to_h, **)
      end

      # Checks if results should be numbered.
      #
      # @return [Boolean] True if indexed is enabled
      def indexed? = indexed

      # Checks if this is a metadata format configuration.
      #
      # @return [Boolean] True if snippet or date are set
      def metadata_format? = !snippet.nil? || !date.nil?

      # Returns field keys for result extraction.
      #
      # @return [Hash] Field keys (:title, :link, :description)
      def field_keys
        { title:, link:, description: }
      end
    end
  end
end
