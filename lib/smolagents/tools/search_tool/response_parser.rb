module Smolagents
  module Tools
    class SearchTool < Tool
      # Parses and extracts results from API responses.
      module ResponseParser
        private

        # Parses HTTP response body and extracts structured results.
        #
        # @param body [String] Raw HTTP response body
        # @return [Array<Hash>] Extracted and formatted search results
        def parse_response(body)
          data = parse_body(body)
          extract_results(data)
        end

        # Parses response body according to configured parser type (JSON, HTML, XML, etc).
        #
        # @param body [String] Raw response body
        # @return [Object] Parsed data structure (Hash, Nokogiri::Document, etc)
        def parse_body(body)
          case config.parser_type
          in :json then parse_json(body)
          in :html then parse_html(body)
          in :xml then parse_xml(body)
          in :rss then parse_rss_items(body, limit: max_results)
          in :atom then parse_atom_entries(body, limit: max_results)
          else body
          end
        end

        # Extracts search results from parsed data, handling feeds and HTML parsing.
        #
        # @param data [Object] Parsed response data
        # @return [Array<Hash>] Array of result hashes with title, link, description
        def extract_results(data)
          return data if feed_parser?
          return extract_html_results(data) if html_with_selector?

          results = dig_results(data)
          mapped = map_results_with_link_builder(Array(results))
          strip_html_from_results(mapped)
        end

        # Checks if the parser type is RSS or Atom feed.
        #
        # @return [Boolean] True if parser handles RSS/Atom feeds
        def feed_parser? = %i[rss atom].include?(config.parser_type)

        # Checks if HTML parsing with CSS selector is configured.
        #
        # @return [Boolean] True if HTML parser with result selector is configured
        def html_with_selector? = config.parser_type == :html && config.html_result_selector

        # Navigates nested data structure using configured result path keys.
        #
        # @param data [Object] Data structure to navigate
        # @return [Array] Results at the path or empty array if not found
        def dig_results(data)
          config.results_path_keys.any? ? data.dig(*config.results_path_keys) || [] : data
        end

        # Extracts search results from HTML document using CSS selectors.
        #
        # @param doc [Nokogiri::Document] Parsed HTML document
        # @return [Array<Hash>] Extracted result hashes up to max_results limit
        def extract_html_results(doc)
          results = []

          doc.css(config.html_result_selector).each do |row|
            break if results.size >= max_results

            result = extract_html_fields(row)
            results << result if result_valid?(result)
          end

          strip_html_from_results(results)
        end

        # Extracts field values from an HTML element row using configured selectors.
        #
        # @param row [Nokogiri::XML::Element] HTML element containing result data
        # @return [Hash] Extracted fields (title, link, description, etc)
        def extract_html_fields(row)
          config.html_field_configs.each_with_object({}) do |(field, opts), result|
            element = find_element(row, opts)
            next unless element

            result[field] = extract_and_format_value(element, opts)
          end
        end

        # Finds an HTML element using base and optional nested selectors.
        #
        # @param row [Nokogiri::XML::Element] Base element to search within
        # @param opts [Hash] Options with :selector and optional :nested keys
        # @return [Nokogiri::XML::Element, nil] Found element or nil
        def find_element(row, opts)
          base = row.at_css(opts[:selector])
          opts[:nested] ? base&.at_css(opts[:nested]) : base
        end

        # Extracts and formats a field value with optional prefix/suffix affixes.
        #
        # @param element [Nokogiri::XML::Element] HTML element
        # @param opts [Hash] Options with :extract, :prefix, :suffix keys
        # @return [String, nil] Formatted value or nil
        def extract_and_format_value(element, opts)
          value = extract_element_value(element, opts[:extract])
          value = format_with_affixes(value, opts[:prefix], opts[:suffix])
          value&.strip
        end

        # Formats a value with prefix and suffix affixes.
        #
        # @param value [String, nil] The value to format
        # @param prefix [String, nil] Prefix to prepend
        # @param suffix [String, nil] Suffix to append
        # @return [String, nil] Formatted value or nil if value is nil
        def format_with_affixes(value, prefix, suffix)
          return nil unless value

          "#{prefix}#{value}#{suffix}"
        end

        # Extracts a value from an HTML element by specified method.
        #
        # @param element [Nokogiri::XML::Element] HTML element
        # @param extract_type [Symbol] Extraction method (:text, :href, :src, or attribute name)
        # @return [String, nil] Extracted value
        def extract_element_value(element, extract_type)
          case extract_type
          in :text then element.text
          in :href then element["href"]
          in :src then element["src"]
          else element[extract_type.to_s]
          end
        end

        # Checks if a result has required fields (title or link).
        #
        # @param result [Hash] Result hash to validate
        # @return [Boolean] True if result has title or link
        def result_valid?(result)
          result[:title] || result[:link]
        end

        # Maps and transforms results, optionally building custom links.
        #
        # @param results [Array<Hash>] Results to map with field mappings
        # @return [Array<Hash>] Mapped results with transformed fields
        def map_results_with_link_builder(results)
          mapped = map_results(results, **config.field_mappings)

          return mapped unless config.link_builder_proc

          results.zip(mapped).map do |raw, result|
            result[:link] = instance_exec(raw, &config.link_builder_proc)
            result
          end
        end

        # Removes HTML tags from specified result fields.
        #
        # @param results [Array<Hash>] Results to strip HTML from
        # @return [Array<Hash>] Results with HTML stripped from configured fields
        def strip_html_from_results(results)
          return results if config.strip_html_fields.empty?

          results.map do |result|
            config.strip_html_fields.each do |field|
              result[field] = strip_html_tags(result[field]) if result[field]
            end
            result
          end
        end

        # Removes HTML tags from text using regex.
        #
        # @param text [String] Text potentially containing HTML tags
        # @return [String] Text with HTML tags removed
        def strip_html_tags(text)
          text.to_s.gsub(/<[^>]*>/, "")
        end
      end
    end
  end
end
