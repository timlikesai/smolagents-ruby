module Smolagents
  module Utilities
    module PatternMatching
      # Extracts final_answer calls from LLM responses.
      # Handles trailing text, balanced parentheses, and malformed outputs.
      module FinalAnswer
        # Mutable struct for performance in tight character loop
        # rubocop:disable Smolagents/PreferDataDefine -- needs mutation for character parsing
        ParseState = Struct.new(:depth, :in_string, :string_char, :escape_next, :result)
        # rubocop:enable Smolagents/PreferDataDefine

        class << self
          def extract_standalone(text)
            match = text.match(/final_answer\s*\(\s*answer:\s*(.+?)\s*\)\s*(?:$|[\n#])/mi)
            return "final_answer(answer: #{clean_answer_value(match[1].strip)})" if match

            extract_with_balanced_parens(text)
          end

          def maybe_append(code, text)
            return code if code.include?("final_answer")

            (fa = extract_standalone(text)) ? "#{code}\n#{fa}" : code
          end

          def extract_balanced_value(str)
            return nil if str.nil? || str.empty?

            state = ParseState.new(0, false, nil, false, +"")
            str.each_char { |c| return state.result.strip if process_char(c, state) == :done }
            state.result.strip.empty? ? nil : state.result.strip
          end

          def clean_answer_value(str)
            str.sub(/\s*#.*$/, "").sub(/\s+(?:and|because|since|so|this|the|I)\b.*$/i, "").strip
          end

          def balance_parens(str)
            d = 0
            str.each_char.with_index do |c, i|
              d += { "(" => 1, ")" => -1 }.fetch(c, 0)
              return str[0...i] if d.negative?
            end
            str
          end

          private

          def extract_with_balanced_parens(text)
            match = text.match(/final_answer\s*\(\s*answer:\s*/mi)
            return nil unless match

            value = extract_balanced_value(text[match.end(0)..])
            value ? "final_answer(answer: #{value})" : nil
          end

          def process_char(char, state)
            if state.escape_next
              state.result << char
              state.escape_next = false
              return nil
            end

            return handle_escape(char, state) if char == "\\"
            return handle_string_char(char, state) if state.in_string

            handle_normal_char(char, state)
          end

          def handle_escape(char, state)
            state.escape_next = true
            state.result << char
            nil
          end

          def handle_string_char(char, state)
            state.result << char
            state.in_string = false if char == state.string_char
            nil
          end

          def handle_normal_char(char, state)
            case char
            when '"', "'" then state.in_string = (state.string_char = char)
            when "(" then state.depth += 1
            when ")" then return :done if state.depth.zero? || (state.depth -= 1).nil?
            end
            (state.result << char) && nil
          end
        end
      end
    end
  end
end
