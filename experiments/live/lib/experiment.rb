# Experiment DSL
#
# Define experiments with models, tools, tasks, and validation.

module LiveExperiments
  module Experiment
    @registry = {}

    def self.define(name, &block)
      definition = Definition.new(name)
      definition.instance_eval(&block)
      @registry[name] = definition
    end

    def self.registry = @registry
    def self.[](name) = @registry[name]
    def self.all = @registry.values

    # Experiment definition
    class Definition
      attr_reader :name, :model_configs, :tool_configs, :task_list, :settings

      def initialize(name)
        @name = name
        @description_text = nil
        @model_configs = {}
        @tool_configs = []
        @task_list = []
        @settings = {
          iterations: 1,
          timeout: 120,
          max_steps: 15,
          checkpoint_every: 1,
          parallel: false
        }
      end

      def description(text = nil)
        text ? @description_text = text : @description_text
      end

      def models(&block)
        ModelDSL.new(@model_configs).instance_eval(&block)
      end

      def tools(&block)
        ToolDSL.new(@tool_configs).instance_eval(&block)
      end

      def tasks(&block)
        TaskDSL.new(@task_list).instance_eval(&block)
      end

      def config(&block)
        ConfigDSL.new(@settings).instance_eval(&block)
      end

      def total_runs
        @model_configs.size * @task_list.size * @settings[:iterations]
      end
    end

    # Model configuration DSL
    class ModelDSL
      def initialize(registry)
        @registry = registry
      end

      # Add a model with a factory lambda
      def add(name, factory = nil, &block)
        @registry[name] = factory || block
      end

      # Use a pre-configured model from infrastructure
      def use(name, method_name = name)
        @registry[name] = -> { Infrastructure::ModelFactories.send(method_name) }
      end
    end

    # Tool configuration DSL
    class ToolDSL
      def initialize(list)
        @list = list
      end

      # Add a mock tool
      def mock(name, description, inputs = {}, &block)
        @list << { type: :mock, name:, description:, inputs:, handler: block }
      end

      # Add a real tool from the registry
      def real(name)
        @list << { type: :real, name: }
      end

      # Add an inline tool
      def inline(name, description, inputs = {}, &block)
        @list << { type: :inline, name:, description:, inputs:, handler: block }
      end
    end

    # Task configuration DSL
    class TaskDSL
      def initialize(list)
        @list = list
      end

      # Add a task with validation
      def task(prompt, expect: nil, validate: nil, tags: [], difficulty: :medium)
        @list << {
          prompt:,
          expect:,
          validate:,
          tags: Array(tags),
          difficulty:
        }
      end

      # Add multiple similar tasks
      def tasks_from(items, template:, tags: [])
        items.each do |item|
          prompt = template.is_a?(Proc) ? template.call(item) : template % item
          @list << { prompt:, tags: Array(tags), difficulty: :medium }
        end
      end
    end

    # Settings DSL
    class ConfigDSL
      def initialize(settings)
        @settings = settings
      end

      def iterations(n) = @settings[:iterations] = n
      def timeout(n) = @settings[:timeout] = n
      def max_steps(n) = @settings[:max_steps] = n
      def checkpoint_every(n) = @settings[:checkpoint_every] = n
      def parallel(bool) = @settings[:parallel] = bool
    end
  end
end
