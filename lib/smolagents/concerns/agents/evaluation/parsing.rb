module Smolagents
  module Concerns
    module Evaluation
      # Parses evaluation responses into structured results.
      #
      # Extracts status, content, and optional confidence from model output.
      module Parsing
        # Status patterns for response parsing.
        # Each maps a regex to a status symbol and capture group interpretation.
        STATUS_PATTERNS = {
          done: /\ADONE:\s*(.+?)(?:\nCONFIDENCE:|$)/mi,
          continue: /\ACONTINUE:\s*(.+?)(?:\nCONFIDENCE:|$)/mi,
          stuck: /\ASTUCK:\s*(.+?)(?:\nCONFIDENCE:|$)/mi
        }.freeze

        CONFIDENCE_PATTERN = /CONFIDENCE:\s*([\d.]+)/i

        # Parses the evaluation response using pattern matching.
        #
        # @param content [String] Raw model response
        # @param token_usage [TokenUsage, nil] Tokens used
        # @return [EvaluationResult]
        def parse_evaluation(content, token_usage = nil)
          text = content.strip
          confidence = extract_confidence(text)
          parse_evaluation_text(text, confidence, token_usage)
        end

        private

        def parse_evaluation_text(text, confidence, token_usage)
          STATUS_PATTERNS.each do |status, pattern|
            next unless text.match?(pattern)

            text =~ pattern
            captured = ::Regexp.last_match(1).strip
            return build_result_for_status(status, captured, confidence, token_usage)
          end

          # Unrecognized format defaults to continue with low confidence
          Types::EvaluationResult.continue(reasoning: text, confidence: 0.3, token_usage:)
        end

        def build_result_for_status(status, captured, confidence, token_usage)
          opts = { token_usage: }
          opts[:confidence] = confidence if confidence

          case status
          when :done
            Types::EvaluationResult.achieved(answer: captured, **opts)
          when :continue
            Types::EvaluationResult.continue(reasoning: captured, **opts)
          when :stuck
            Types::EvaluationResult.stuck(reasoning: captured, **opts)
          end
        end

        # Extracts confidence score from evaluation response if present.
        #
        # @param text [String] Raw model response
        # @return [Float, nil] Confidence score or nil for default
        def extract_confidence(text)
          return nil unless text =~ CONFIDENCE_PATTERN

          ::Regexp.last_match(1).to_f.clamp(0.0, 1.0)
        end
      end
    end
  end
end
