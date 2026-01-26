# Ruby-native context formatting for code agents.
#
# Formats context contributions as Ruby comments, making the
# context feel natural for agents that think in Ruby code.
#
# @example Standard section
#   RubyPresenter.section("Goal", "Find Ruby release notes")
#   # => "# == Goal ==\n# Find Ruby release notes"
#
# @example List section
#   RubyPresenter.list_section("Plan", ["Search", "Extract", "Summarize"])
#   # => "# == Plan ==\n# 1. Search\n# 2. Extract\n# 3. Summarize"
module Smolagents
  module Context
    module RubyPresenter
      HEADER_CHAR = "=".freeze
      COMMENT_PREFIX = "# ".freeze
      BOX_TOP = "# \u2554#{"═" * 66}\u2557".freeze
      BOX_BOTTOM = "# \u255a#{"═" * 66}\u255d".freeze

      class << self
        # Formats a standard section with header and content.
        # @param title [String] section title
        # @param content [String] section content
        # @return [String] formatted section
        def section(title, content)
          header = "#{COMMENT_PREFIX}== #{title} =="
          body = content.lines.map { |line| "#{COMMENT_PREFIX}#{line.chomp}" }.join("\n")
          "#{header}\n#{body}"
        end

        # Formats a list section with numbered items.
        # @param title [String] section title
        # @param items [Array<String>] list items
        # @param markers [Hash] optional item markers {index => marker}
        # @return [String] formatted list section
        def list_section(title, items, markers: {})
          header = "#{COMMENT_PREFIX}== #{title} =="
          body = items.map.with_index(1) do |item, i|
            marker = markers[i - 1] || " "
            "#{COMMENT_PREFIX}#{i}. [#{marker}] #{item}"
          end.join("\n")
          "#{header}\n#{body}"
        end

        # Formats a key-value section.
        # @param title [String] section title
        # @param pairs [Hash] key-value pairs
        # @return [String] formatted kv section
        def kv_section(title, pairs)
          header = "#{COMMENT_PREFIX}== #{title} =="
          max_key = pairs.keys.map { |k| k.to_s.size }.max || 0
          body = pairs.map do |key, value|
            "#{COMMENT_PREFIX}#{key.to_s.ljust(max_key)}: #{value}"
          end.join("\n")
          "#{header}\n#{body}"
        end

        # Formats a tools section showing available tools.
        # @param tools [Array<Hash>] tools with :name, :signature, :description
        # @return [String] formatted tools section
        def tools_section(tools)
          header = "#{COMMENT_PREFIX}== Available Tools =="
          max_sig = tools.map { |t| t[:signature].size }.max || 0
          body = tools.map do |tool|
            sig = tool[:signature].ljust(max_sig)
            "#{COMMENT_PREFIX}#{sig}  # #{tool[:description]}"
          end.join("\n")
          "#{header}\n#{body}"
        end

        # Formats the continuation prompt.
        # @return [String] continuation prompt
        def continuation
          "#{COMMENT_PREFIX}Continue from here:"
        end

        # Formats a boxed header for context blocks.
        # @param title [String] header title
        # @return [String] boxed header
        def boxed_header(title)
          padded = title.center(64)
          middle = "# \u2551 #{padded} \u2551"
          "#{BOX_TOP}\n#{middle}\n#{BOX_BOTTOM}"
        end

        # Combines multiple sections into a context block.
        # @param sections [Array<String>] formatted sections
        # @return [String] combined context block
        def context_block(sections) = sections.compact.join("\n\n")

        # Formats progress indicator (e.g., for plans).
        # @param current [Integer] current step
        # @param total [Integer] total steps
        # @return [String] progress string
        def progress(current, total)
          remaining = total - current
          "step #{current} of #{total} (#{remaining} remaining)"
        end

        # Formats a status indicator.
        # @param name [String] item name
        # @param status [Symbol] :success, :failure, :pending
        # @param detail [String, nil] optional detail
        # @return [String] formatted status
        def status(name, status, detail = nil)
          icon = case status
                 when :success then "\u2713"
                 when :failure then "\u2717"
                 when :pending then "\u2192"
                 else "?"
                 end
          base = "#{name} #{icon}"
          detail ? "#{base} (#{detail})" : base
        end
      end
    end
  end
end
