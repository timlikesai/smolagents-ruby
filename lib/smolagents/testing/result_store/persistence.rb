require "json"

module Smolagents
  module Testing
    class ResultStore
      # File-based persistence for test results.
      #
      # Handles reading and writing JSON files organized by model ID.
      # Results are stored in a directory structure: path/model_id/test_name_timestamp.json
      module Persistence
        def self.included(base)
          base.attr_reader :path
        end

        private

        def initialize_persistence(path)
          @path = Pathname.new(path)
          @path.mkpath unless @path.exist?
        end

        def write_result(model_id, test_name, data)
          dir = @path / sanitize(model_id)
          dir.mkpath
          file = dir / "#{sanitize(test_name)}_#{data[:timestamp].tr(":", "-")}.json"
          file.write(JSON.pretty_generate(data))
        end

        def load_results
          @path.glob("**/*.json").filter_map do |file|
            JSON.parse(file.read, symbolize_names: true)
          rescue JSON::ParserError
            nil
          end
        end

        def sanitize(name) = name.to_s.gsub(/[^a-zA-Z0-9_-]/, "_")
      end
    end
  end
end
