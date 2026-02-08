# frozen_string_literal: true

require "securerandom"

module Smolagents
  module Models
    module FunctionGemma
      # Parses FunctionGemma output format into ToolCall/SpeculativeToolCall types.
      #
      # Input format:
      #   <start_function_call>call:name{key:<escape>val<escape>}<end_function_call>
      #
      # @example Basic parsing
      #   calls = Parser.parse(raw_output)
      #   calls.first.name       # => "get_weather"
      #   calls.first.arguments  # => { "location" => "London" }
      #
      # @example With confidence scoring
      #   results = Parser.parse_speculative(raw_output)
      #   results.first.confidence      # => 0.85
      #   results.first.high_confidence? # => true
      module Parser
        START_TAG = "<start_function_call>"
        END_TAG = "<end_function_call>"
        ESCAPE_TAG = "<escape>"
        CALL_PREFIX = "call:"

        class << self
          # Parses raw output into ToolCall instances.
          #
          # @param raw_output [String] FunctionGemma output string
          # @return [Array<Types::ToolCall>] Parsed tool calls
          def parse(raw_output)
            return [] if raw_output.nil? || raw_output.empty?

            extract_call_blocks(raw_output).filter_map { |block| parse_single(block) }
          end

          # Parses raw output into SpeculativeToolCall instances with confidence.
          #
          # @param raw_output [String] FunctionGemma output string
          # @param base_confidence [Float] Base confidence (0.0-1.0)
          # @return [Array<Types::SpeculativeToolCall>] Calls with confidence
          def parse_speculative(raw_output, base_confidence: 0.7)
            calls = parse(raw_output)
            calls.map.with_index do |call, idx|
              confidence = calculate_confidence(call, idx, calls.size, base_confidence)
              Types::SpeculativeToolCall.from_function_gemma(call, confidence:)
            end
          end

          # Parses a single function call block.
          #
          # @param block [String] Content between delimiters (without tags)
          # @return [Types::ToolCall, nil] Parsed call or nil if malformed
          def parse_single(block)
            body = block.strip
            return nil unless body.start_with?(CALL_PREFIX)

            body = body.delete_prefix(CALL_PREFIX)
            name, params_block = extract_name_and_params(body)
            return nil if name.nil? || name.empty?

            arguments = parse_arguments(params_block)
            Types::ToolCall.new(name:, arguments:, id: generate_id)
          end

          private

          def extract_call_blocks(raw_output)
            blocks = []
            remaining = raw_output

            while (start_idx = remaining.index(START_TAG))
              after_start = start_idx + START_TAG.length
              end_idx = remaining.index(END_TAG, after_start)
              break unless end_idx

              blocks << remaining[after_start...end_idx]
              remaining = remaining[(end_idx + END_TAG.length)..]
            end

            blocks
          end

          def extract_name_and_params(body)
            brace_idx = body.index("{")
            return [body, ""] unless brace_idx

            name = body[0...brace_idx].strip
            close_idx = body.rindex("}")
            params = close_idx ? body[(brace_idx + 1)...close_idx] : ""
            [name, params]
          end

          def parse_arguments(params_block)
            return {} if params_block.nil? || params_block.strip.empty?

            segments = split_preserving_escapes(params_block.strip)
            segments.each_with_object({}) do |segment, hash|
              key, value = parse_key_value(segment)
              hash[key] = value if key && !key.empty?
            end
          end

          def split_preserving_escapes(text)
            segments = []
            current = +""
            in_escape = false

            idx = 0
            while idx < text.length
              if text[idx..].start_with?(ESCAPE_TAG)
                in_escape = !in_escape
                current << ESCAPE_TAG
                idx += ESCAPE_TAG.length
              elsif text[idx] == "," && !in_escape
                segments << current.strip unless current.strip.empty?
                current = +""
                idx += 1
              else
                current << text[idx]
                idx += 1
              end
            end

            segments << current.strip unless current.strip.empty?
            segments
          end

          def parse_key_value(segment)
            colon_idx = segment.index(":")
            return [nil, nil] unless colon_idx

            key = segment[0...colon_idx].strip
            raw_value = segment[(colon_idx + 1)..].strip
            value = strip_escape_tags(raw_value)
            [key, value]
          end

          def strip_escape_tags(value)
            value.gsub(ESCAPE_TAG, "")
          end

          def generate_id = "fg_call_#{SecureRandom.hex(4)}"

          def calculate_confidence(call, index, total_calls, base)
            confidence = base
            confidence -= 0.1 if call.arguments.empty? && call.name != "list_tools"
            confidence -= 0.05 * index if total_calls > 1
            confidence.clamp(0.0, 1.0)
          end
        end
      end
    end
  end
end
