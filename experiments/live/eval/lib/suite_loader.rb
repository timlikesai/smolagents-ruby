# Suite Loader
#
# Loads YAML test suite definitions and converts them to runnable test objects.

require "yaml"

module LiveExperiments
  module Eval
    class SuiteLoader
      SUITES_DIR = File.expand_path("../suites", __dir__)

      # Load a specific suite by name
      def load(suite_name)
        path = File.join(SUITES_DIR, "#{suite_name}.yml")
        raise ArgumentError, "Suite not found: #{suite_name}" unless File.exist?(path)

        parse_suite(YAML.safe_load(File.read(path), permitted_classes: [Symbol]))
      end

      # Load all available suites
      def load_all
        Dir.glob(File.join(SUITES_DIR, "*.yml")).map do |path|
          suite_name = File.basename(path, ".yml")
          [suite_name, load(suite_name)]
        end.to_h
      end

      # List available suite names
      def available
        Dir.glob(File.join(SUITES_DIR, "*.yml")).map { |p| File.basename(p, ".yml") }
      end

      private

      def parse_suite(yaml)
        Suite.new(
          name: yaml.dig("suite", "name"),
          description: yaml.dig("suite", "description"),
          tier: yaml.dig("suite", "tier") || 1,
          tests: parse_tests(yaml["tests"] || [])
        )
      end

      def parse_tests(tests)
        tests.map.with_index do |t, idx|
          Test.new(
            id: t["id"] || "test_#{idx + 1}",
            name: t["name"],
            category: t["category"],
            prompt: t["prompt"],
            tools: t["tools"] || [],
            expect: parse_expectations(t["expect"]),
            timeout: t["timeout"] || 30,
            tags: t["tags"] || []
          )
        end
      end

      def parse_expectations(expect)
        return Expectation.new if expect.nil?

        Expectation.new(
          contains: Array(expect["contains"]),
          not_contains: Array(expect["not_contains"]),
          tool_called: expect["tool_called"],
          tool_args_match: expect["tool_args_match"],
          final_answer: expect["final_answer"],
          min_steps: expect["min_steps"],
          max_steps: expect["max_steps"]
        )
      end
    end

    # Immutable suite definition
    Suite = Data.define(:name, :description, :tier, :tests)

    # Immutable test definition
    Test = Data.define(:id, :name, :category, :prompt, :tools, :expect, :timeout, :tags)

    # Immutable expectation definition
    Expectation = Data.define(
      :contains,
      :not_contains,
      :tool_called,
      :tool_args_match,
      :final_answer,
      :min_steps,
      :max_steps
    ) do
      def initialize(contains: [], not_contains: [], tool_called: nil,
                     tool_args_match: nil, final_answer: nil, min_steps: nil, max_steps: nil)
        super
      end
    end
  end
end
