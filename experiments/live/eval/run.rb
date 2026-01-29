#!/usr/bin/env ruby
# Evaluation Framework CLI
#
# Usage:
#   ruby eval/run.rb --suite basic_reasoning --endpoint llama-cpp-ultra
#   ruby eval/run.rb --all --endpoint macbook-pro-m4
#   ruby eval/run.rb --report
#   ruby eval/run.rb --list

require "optparse"
require_relative "../lib/bootstrap"
require_relative "lib/suite_loader"
require_relative "lib/evaluator"
require_relative "lib/result_store"
require_relative "lib/reporter"
require_relative "lib/tools"

module LiveExperiments
  module Eval
    class CLI
      def initialize(args)
        @options = parse_options(args)
        @loader = SuiteLoader.new
        @store = ResultStore.new
      end

      def run
        case
        when @options[:list]
          list_suites
        when @options[:report]
          generate_report
        when @options[:suite] || @options[:all]
          run_evaluation
        else
          puts "Use --help for usage information"
        end
      end

      private

      def parse_options(args)
        options = {}
        OptionParser.new do |opts|
          opts.banner = "Usage: ruby eval/run.rb [options]"

          opts.on("-s", "--suite SUITE", "Run specific suite") { |s| options[:suite] = s }
          opts.on("-a", "--all", "Run all suites") { options[:all] = true }
          opts.on("-e", "--endpoint NAME", "Endpoint (llama-cpp-ultra, macbook-pro-m4, mac-studio)") do |e|
            options[:endpoint] = e
          end
          opts.on("-m", "--model ID", "Model ID to test") { |m| options[:model_id] = m }
          opts.on("-r", "--report", "Generate comparison report") { options[:report] = true }
          opts.on("-l", "--list", "List available suites") { options[:list] = true }
          opts.on("-v", "--verbose", "Verbose output") { options[:verbose] = true }
          opts.on("-h", "--help", "Show help") do
            puts opts
            exit
          end
        end.parse!(args)
        options
      end

      def list_suites
        puts "Available test suites:"
        puts ""
        @loader.available.each do |name|
          suite = @loader.load(name)
          puts "  #{name} (Tier #{suite.tier})"
          puts "    #{suite.description}"
          puts "    Tests: #{suite.tests.size}"
          puts ""
        end
      end

      def generate_report
        reporter = Reporter.new(store: @store)
        report = reporter.generate_comparison
        puts report
      end

      def run_evaluation
        endpoint_config = resolve_endpoint
        return unless endpoint_config

        model = build_model(endpoint_config)
        return unless model

        suites = resolve_suites
        tools = Tools.standard_set

        puts "=" * 60
        puts "Evaluation Run"
        puts "=" * 60
        puts "Endpoint: #{@options[:endpoint]}"
        puts "Model: #{model.model_id}"
        puts "Suites: #{suites.map(&:name).join(", ")}"
        puts "=" * 60

        suites.each { |suite| run_suite(suite, model, tools) }

        puts "\n#{"=" * 60}"
        puts "Evaluation Complete"
        puts "=" * 60
      end

      def resolve_endpoint
        name = @options[:endpoint] || "llama-cpp-ultra"
        config = Infrastructure::ENDPOINTS[name]

        unless config
          puts "Unknown endpoint: #{name}"
          puts "Available: #{Infrastructure::ENDPOINTS.keys.join(", ")}"
          return nil
        end

        # Health check
        checker = Infrastructure::HealthChecker.new
        status = checker.check_endpoint(config[:endpoint])

        if status[:status] != :healthy
          puts "Endpoint #{name} is not reachable: #{status[:status]}"
          return nil
        end

        puts "Endpoint #{name}: OK (#{status[:latency_ms]}ms)"
        config
      end

      def build_model(endpoint_config)
        # Discover model if not specified
        model_id = @options[:model_id] || discover_model(endpoint_config[:endpoint])
        return nil unless model_id

        Smolagents.model(:openai)
                  .base_url(endpoint_config[:endpoint])
                  .id(model_id)
                  .timeout(60)
                  .server_type(endpoint_config[:server_type])
                  .build
      end

      def discover_model(endpoint)
        checker = Infrastructure::HealthChecker.new
        status = checker.check_endpoint(endpoint)

        if status[:models].empty?
          puts "No models loaded at endpoint"
          return nil
        end

        model_id = status[:models].first
        puts "Using model: #{model_id}"
        model_id
      end

      def resolve_suites
        if @options[:all]
          @loader.available.map { |name| @loader.load(name) }
        else
          [@loader.load(@options[:suite])]
        end
      end

      def run_suite(suite, model, tools)
        puts "\n--- Suite: #{suite.name} (Tier #{suite.tier}) ---"
        puts suite.description
        puts ""

        evaluator = Evaluator.new(model:, tools:)

        progress = lambda do |current, total, name|
          puts "  [#{current}/#{total}] #{name}..."
        end

        result = evaluator.run_suite(suite, progress:)

        # Store result
        path = @store.store(result)
        puts "\nResults saved to: #{path}"

        # Print summary
        print_summary(result)
      end

      def print_summary(result)
        puts "\nSummary:"
        puts "  Total:    #{result.summary.total}"
        puts "  Passed:   #{result.summary.passed}"
        puts "  Failed:   #{result.summary.failed}"
        puts "  Pass Rate: #{(result.summary.pass_rate * 100).round}%"
        puts "  Avg Time:  #{result.summary.avg_duration_ms}ms"

        # Failed tests
        failed = result.test_results.reject(&:passed)
        return unless failed.any?

        puts "\nFailed tests:"
        failed.each do |tr|
          puts "  - #{tr.test_name}: #{tr.error || "expectation not met"}"
        end
      end
    end
  end
end

# Run CLI
LiveExperiments::Eval::CLI.new(ARGV).run
