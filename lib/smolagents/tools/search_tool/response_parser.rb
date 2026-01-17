module Smolagents
  module Tools
    class SearchTool < Tool
      # Parses and extracts results from API responses.
      module ResponseParser
        private

        def parse_response(body)
          data = parse_body(body)
          extract_results(data)
        end

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

        def extract_results(data)
          return data if feed_parser?
          return extract_html_results(data) if html_with_selector?

          results = dig_results(data)
          mapped = map_results_with_link_builder(Array(results))
          strip_html_from_results(mapped)
        end

        def feed_parser? = %i[rss atom].include?(config.parser_type)
        def html_with_selector? = config.parser_type == :html && config.html_result_selector

        def dig_results(data)
          config.results_path_keys.any? ? data.dig(*config.results_path_keys) || [] : data
        end

        def extract_html_results(doc)
          results = []

          doc.css(config.html_result_selector).each do |row|
            break if results.size >= max_results

            result = extract_html_fields(row)
            results << result if result_valid?(result)
          end

          strip_html_from_results(results)
        end

        def extract_html_fields(row)
          config.html_field_configs.each_with_object({}) do |(field, opts), result|
            element = find_element(row, opts)
            next unless element

            result[field] = extract_and_format_value(element, opts)
          end
        end

        def find_element(row, opts)
          base = row.at_css(opts[:selector])
          opts[:nested] ? base&.at_css(opts[:nested]) : base
        end

        def extract_and_format_value(element, opts)
          value = extract_element_value(element, opts[:extract])
          value = format_with_affixes(value, opts[:prefix], opts[:suffix])
          value&.strip
        end

        def format_with_affixes(value, prefix, suffix)
          return nil unless value

          "#{prefix}#{value}#{suffix}"
        end

        def extract_element_value(element, extract_type)
          case extract_type
          in :text then element.text
          in :href then element["href"]
          in :src then element["src"]
          else element[extract_type.to_s]
          end
        end

        def result_valid?(result)
          result[:title] || result[:link]
        end

        def map_results_with_link_builder(results)
          mapped = map_results(results, **config.field_mappings)

          return mapped unless config.link_builder_proc

          results.zip(mapped).map do |raw, result|
            result[:link] = instance_exec(raw, &config.link_builder_proc)
            result
          end
        end

        def strip_html_from_results(results)
          return results if config.strip_html_fields.empty?

          results.map do |result|
            config.strip_html_fields.each do |field|
              result[field] = strip_html_tags(result[field]) if result[field]
            end
            result
          end
        end

        def strip_html_tags(text)
          text.to_s.gsub(/<[^>]*>/, "")
        end
      end
    end
  end
end
