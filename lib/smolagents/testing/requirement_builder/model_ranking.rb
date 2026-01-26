module Smolagents
  module Testing
    module RequirementBuilderConcerns
      # Model ranking functionality for RequirementBuilder.
      #
      # Extracts the model ranking and scoring logic into a reusable concern.
      # Requires the host class to respond to #all_test_cases.
      module ModelRanking
        # Rank models by how well they meet requirements.
        #
        # @param candidates [Array] Models to evaluate
        # @yield [TestCase, Object] Block that runs a test on a model, returns TestResult
        # @return [Array<ModelScore>] Sorted scores (best first)
        def rank_models(candidates)
          scores = candidates.map do |model_info|
            results = all_test_cases.map { |tc| yield(tc, model_info) }
            build_score(model_info, results)
          end
          sort_scores(scores)
        end

        private

        def build_score(model_info, results)
          ModelScore.new(
            model_id: extract_model_id(model_info),
            capabilities_passed: passed_capabilities(results),
            pass_rate: calculate_pass_rate(results),
            results:
          )
        end

        def extract_model_id(model_info)
          model_info.respond_to?(:model_id) ? model_info.model_id : model_info.to_s
        end

        def passed_capabilities(results)
          results.select(&:passed).map { |r| r.test_case.capability }.uniq
        end

        def calculate_pass_rate(results)
          results.count(&:passed) / results.size.to_f
        end

        def sort_scores(scores)
          scores.sort_by { |score| [-score.pass_rate, score.model_id] }
        end
      end
    end
  end
end
