require_relative "../formatting/structure"
require_relative "observation_router/summarizer"

module Smolagents
  module Concerns
    # Formats tool observations for agent context.
    #
    # Uses StructureFormatting from the unified formatting system to describe
    # data structures with access patterns. Optionally adds LLM summarization.
    #
    # == Observation Modes
    #
    # - +:with_summary+ (default) - Structure + LLM summary
    # - +:structure_only+ - Structure only, no LLM call (faster)
    #
    # @example Default behavior (structure + summary)
    #   agent = Smolagents.agent.model { model }.build
    #
    # @example Structure only (no extra LLM call)
    #   agent = Smolagents.agent.model { model }.observe(:structure_only).build
    #
    # @example With summary using a fast model
    #   agent = Smolagents.agent
    #     .model { main_model }
    #     .observe(:with_summary) { fast_model }
    #     .build
    #
    # @see Concerns::StructureFormatting For data structure descriptions
    module ObservationRouter
      # Observation formatting mode.
      # @return [Symbol] One of :with_summary, :structure_only
      attr_accessor :observe_mode

      # Model to use for summarization (nil = use agent's model).
      # @return [Model, nil]
      attr_accessor :summarizer_model

      private

      # Formats observations based on mode. Called from CodeExecution#build_observations.
      def route_observations(raw_observation, action_step)
        return raw_observation if skip_observation_formatting?(raw_observation)

        format_observation(raw_observation, action_step)
      rescue StandardError => e
        "[Observation formatting error: #{e.message}]\n#{raw_observation}"
      end

      def format_observation(raw_observation, action_step)
        # Skip LLM summarization for simple results - it adds noise without value
        return format_structure_only(raw_observation, action_step) if primitive_result?(action_step.action_output)

        case @observe_mode
        when :structure_only then format_structure_only(raw_observation, action_step)
        else format_with_summary(raw_observation, action_step)
        end
      end

      # Detects primitive/simple results where LLM summarization adds no value.
      # @param value [Object] The result value to check
      # @return [Boolean] true if value is primitive and should skip summarization
      def primitive_result?(value)
        case value
        when nil, true, false, Numeric, Symbol then true
        when String then value.length < 200
        when Array, Hash then value.empty?
        else false
        end
      end

      def skip_observation_formatting?(obs) = obs.nil? || obs.empty?

      # Format with just data structure (no LLM call).
      def format_structure_only(raw_observation, action_step)
        structure = StructureFormatting.describe(action_step.action_output)

        <<~OBS.strip
          ## Result
          #{structure}

          ## Output
          #{truncate_raw(raw_observation)}
        OBS
      end

      # Format with structure + LLM summary.
      def format_with_summary(raw_observation, action_step)
        structure = StructureFormatting.describe(action_step.action_output)
        summary = generate_summary(extract_tool_names, raw_observation)

        <<~OBS.strip
          ## Result
          #{structure}

          #{summary}
        OBS
      end

      def generate_summary(tool_names, raw_observation)
        model = summarizer_model || @model
        return "" unless model

        with_generation_timeout(context: :summarization) do
          Summarizer.summarize(model:, tool_name: tool_names.join(", "), output: raw_observation, task: current_task)
        end
      end

      def truncate_raw(observation, max: 1000)
        observation.length <= max ? observation : "#{observation.slice(0, max)}...[truncated]"
      end

      def extract_tool_names
        return [] unless @executor.respond_to?(:tool_calls)

        @executor.tool_calls.reject { |c| c.tool_name == "final_answer" }.map(&:tool_name).uniq
      end

      def current_task
        return @current_task if defined?(@current_task) && @current_task
        return @memory.task if @memory.respond_to?(:task)

        "Unknown task"
      end
    end
  end
end
