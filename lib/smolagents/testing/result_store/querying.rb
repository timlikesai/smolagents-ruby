module Smolagents
  module Testing
    class ResultStore
      # Query interface for stored test results.
      #
      # Provides finder methods for retrieving results by model, capability, or test name.
      # Uses metaprogramming to define consistent finder patterns.
      module Querying
        # Returns all stored results.
        #
        # @return [Array<Hash>] All results
        def all_results = load_results

        # Compares results across multiple models.
        #
        # @param model_ids [Array<String>] Model identifiers to compare
        # @return [Hash{String => Array<Hash>}] Results grouped by model
        def compare_models(*model_ids)
          model_ids.flatten.to_h { |id| [id, find_by_model(id)] }
        end

        # Define finder methods using metaprogramming
        # Each finder filters results by a specific field path
        FINDERS = {
          find_by_model: { key: :model_id, path: [:model_id] },
          find_by_capability: { key: :capability, path: %i[test_case capability] },
          find_by_test: { key: :test_name, path: %i[test_case name] }
        }.freeze

        FINDERS.each do |method_name, config|
          define_method(method_name) do |value|
            load_results.select do |result|
              stored_value = config[:path].reduce(result) { |h, k| h&.dig(k) }
              stored_value == value.to_s
            end
          end
        end
      end
    end
  end
end
