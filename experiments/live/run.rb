#!/usr/bin/env ruby
# Live Experiment Runner
#
# Run experiments against real distributed infrastructure.
#
# Usage:
#   ruby experiments/live/run.rb                    # Run all experiments
#   ruby experiments/live/run.rb model_comparison   # Run specific experiment
#   ruby experiments/live/run.rb --list             # List available experiments
#   ruby experiments/live/run.rb --health           # Check infrastructure health

require "bundler/setup"
require_relative "../../lib/smolagents"
require_relative "lib/infrastructure"
require_relative "lib/experiment_logger"
require_relative "lib/experiment"
require_relative "lib/runner"

# Load all experiment definitions
Dir[File.join(__dir__, "definitions", "*.rb")].sort.each { |f| require f }

module LiveExperiments
  class CLI
    def initialize(args)
      @args = args
      @data_dir = File.join(__dir__, "data")
    end

    def run
      case @args.first
      when "--list", "-l"
        list_experiments
      when "--health", "-h"
        check_health
      when "--help"
        show_help
      else
        run_experiments
      end
    end

    private

    def list_experiments
      puts "Available Experiments:"
      puts "=" * 40

      Experiment.all.each do |exp|
        puts "\n#{exp.name}"
        puts "  #{exp.description}" if exp.description
        puts "  Models: #{exp.model_configs.keys.join(", ")}"
        puts "  Tasks: #{exp.task_list.size}"
        puts "  Total runs: #{exp.total_runs}"
      end
    end

    def check_health
      checker = Infrastructure::HealthChecker.new
      puts checker.report
    end

    def show_help
      puts <<~HELP
        Live Experiment Runner

        Usage:
          ruby run.rb                      Run all experiments
          ruby run.rb <name>               Run specific experiment
          ruby run.rb <name> <name2>       Run multiple experiments
          ruby run.rb --list               List available experiments
          ruby run.rb --health             Check infrastructure health
          ruby run.rb --help               Show this help

        Examples:
          ruby run.rb model_comparison
          ruby run.rb code_generation multi_model_patterns
      HELP
    end

    def run_experiments
      # Check health first
      checker = Infrastructure::HealthChecker.new
      unless checker.any_healthy?
        puts "ERROR: No healthy infrastructure endpoints available!"
        puts checker.report
        exit 1
      end

      puts checker.report
      puts

      # Determine which experiments to run
      experiments = if @args.empty?
                      Experiment.all
                    else
                      @args.map { |name| Experiment[name.to_sym] }.compact
                    end

      if experiments.empty?
        puts "No experiments found. Use --list to see available experiments."
        exit 1
      end

      # Run each experiment
      total_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      results = []

      experiments.each do |experiment|
        run_id = "#{experiment.name}_#{Time.now.strftime("%Y%m%d_%H%M%S")}_#{SecureRandom.hex(4)}"
        logger = ExperimentLogger.new(File.join(@data_dir, "logs"), run_id)

        begin
          runner = Runner.new(experiment, logger: logger)
          results << { experiment: experiment.name, results: runner.execute, run_id: run_id }
        rescue StandardError => e
          puts "ERROR running #{experiment.name}: #{e.message}"
          puts e.backtrace.first(5).join("\n")
          logger.error(e)
        ensure
          logger.close
        end
      end

      total_duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - total_start

      # Print summary
      puts "\n#{"=" * 60}"
      puts "ALL EXPERIMENTS COMPLETE"
      puts "=" * 60
      puts "Total duration: #{total_duration.round(1)}s"
      puts "Experiments run: #{results.size}"
      puts "\nResults by experiment:"

      results.each do |r|
        passed = r[:results].count { |x| x[:passed] }
        total = r[:results].size
        puts "  #{r[:experiment]}: #{passed}/#{total} passed (#{r[:run_id]})"
      end

      puts "\nLog directory: #{File.join(@data_dir, "logs")}"
    end
  end
end

# Run CLI
LiveExperiments::CLI.new(ARGV).run
