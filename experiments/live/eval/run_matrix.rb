#!/usr/bin/env ruby
# Matrix Runner - Tests multiple models across endpoints
#
# Usage:
#   ruby eval/run_matrix.rb                    # Run Tier 1 suites on all models
#   ruby eval/run_matrix.rb --tier 2           # Run Tier 1-2 suites
#   ruby eval/run_matrix.rb --quick            # Run first model only per endpoint

require "optparse"
require_relative "../lib/bootstrap"
require_relative "lib/suite_loader"
require_relative "lib/evaluator"
require_relative "lib/result_store"
require_relative "lib/reporter"
require_relative "lib/tools"

module LiveExperiments
  module Eval
    class MatrixRunner
      MODELS_TO_TEST = {
        "macbook-pro-m4" => %w[
          granite-4.0-h-small
          zai-org/glm-4.7-flash
          mlx-community/nvidia-nemotron-3-nano-30b-a3b-mlx
        ],
        "mac-studio" => %w[
          glm-4.7-flash-mlx
          google/gemma-3n-e4b
          nvidia/nemotron-3-nano
        ]
      }.freeze

      def initialize(args)
        @options = parse_options(args)
        @loader = SuiteLoader.new
        @store = ResultStore.new
        @results = []
      end

      def run
        puts "=" * 70
        puts "Model Evaluation Matrix"
        puts "=" * 70

        suites = load_suites
        puts "Suites: #{suites.map(&:name).join(", ")}"
        puts ""

        MODELS_TO_TEST.each do |endpoint_name, model_ids|
          run_endpoint(endpoint_name, model_ids, suites)
        end

        print_summary
        generate_report
      end

      private

      def parse_options(args)
        options = { max_tier: 1 }
        OptionParser.new do |opts|
          opts.on("--tier TIER", Integer, "Max tier (default: 1)") { |t| options[:max_tier] = t }
          opts.on("--quick", "Quick mode - first model per endpoint") { options[:quick] = true }
        end.parse!(args)
        options
      end

      def load_suites
        @loader.available
               .map { |name| @loader.load(name) }
               .select { |s| s.tier <= @options[:max_tier] }
      end

      def run_endpoint(endpoint_name, model_ids, suites)
        config = Infrastructure::ENDPOINTS[endpoint_name]
        return puts "[SKIP] #{endpoint_name}: not configured" unless config

        checker = Infrastructure::HealthChecker.new
        status = checker.check_endpoint(config[:endpoint])

        if status[:status] != :healthy
          puts "[SKIP] #{endpoint_name}: #{status[:status]}"
          return
        end

        puts "\n--- Endpoint: #{endpoint_name} ---"
        puts "Available models: #{status[:models].join(", ")}"

        models_to_run = @options[:quick] ? [model_ids.first] : model_ids

        models_to_run.each do |model_id|
          run_model(endpoint_name, config, model_id, suites)
        end
      end

      def run_model(endpoint_name, config, model_id, suites)
        puts "\n  Model: #{model_id}"

        model = build_model(config, model_id)
        return unless model

        tools = Tools.standard_set
        evaluator = Evaluator.new(model:, tools:)

        suites.each do |suite|
          run_suite_for_model(evaluator, suite, model_id, endpoint_name)
        end
      rescue => e
        puts "    ERROR: #{e.message}"
      end

      def build_model(config, model_id)
        Smolagents.model(:openai)
                  .base_url(config[:endpoint])
                  .id(model_id)
                  .timeout(60)
                  .server_type(config[:server_type])
                  .build
      rescue => e
        puts "    Failed to build model: #{e.message}"
        nil
      end

      def run_suite_for_model(evaluator, suite, model_id, endpoint_name)
        # Skip if already have recent results
        if @store.has_results?(model_id, suite.name) && !@options[:force]
          latest = @store.latest(model_id, suite.name)
          if latest && (Time.now - latest.timestamp) < 3600  # Within last hour
            puts "    #{suite.name}: CACHED #{(latest.summary.pass_rate * 100).round}%"
            @results << { model: model_id, suite: suite.name, result: latest, cached: true }
            return
          end
        end

        print "    #{suite.name}: "

        begin
          result = evaluator.run_suite(suite)
          @store.store(result)

          rate = (result.summary.pass_rate * 100).round
          puts "#{rate}% (#{result.summary.passed}/#{result.summary.total})"

          @results << {
            model: model_id,
            endpoint: endpoint_name,
            suite: suite.name,
            result:,
            cached: false
          }
        rescue => e
          puts "ERROR: #{e.message}"
        end
      end

      def print_summary
        puts "\n#{"=" * 70}"
        puts "Summary"
        puts "=" * 70

        # Group by suite
        by_suite = @results.group_by { |r| r[:suite] }

        by_suite.each do |suite_name, suite_results|
          puts "\n#{suite_name}:"
          suite_results.sort_by { |r| -r[:result].summary.pass_rate }.each do |r|
            rate = (r[:result].summary.pass_rate * 100).round
            cached = r[:cached] ? " (cached)" : ""
            puts "  #{rate}% - #{r[:model]}#{cached}"
          end
        end
      end

      def generate_report
        reporter = Reporter.new(store: @store)
        path = reporter.generate_comparison
        puts "\nReport saved: #{path}"
      end
    end
  end
end

LiveExperiments::Eval::MatrixRunner.new(ARGV).run
