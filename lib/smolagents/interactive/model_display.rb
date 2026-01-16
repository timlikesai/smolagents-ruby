module Smolagents
  module Interactive
    # Display formatting for model lists.
    module ModelDisplay
      extend ColorHelpers

      module_function

      def server_models(server)
        loaded = server.models.select(&:ready?)
        unloaded = server.models.reject(&:ready?)

        puts section("#{server.name} (#{server.base_url})")
        loaded.each { |m| puts model_line(m, ready: true) }
        show_unloaded(unloaded)
        puts
      end

      def model_line(model, ready: true)
        ctx = model.context_length ? dim(" #{model.context_length.to_i / 1000}K") : ""
        caps = model.vision? ? " [#{magenta("vision")}]" : ""
        status = ready ? green("ready") : yellow("not loaded")
        "  #{bold(model.id)}#{ctx}#{caps} #{status}"
      end

      def show_unloaded(models)
        return if models.empty?

        shown = models.first(3)
        hidden = models.size - shown.size

        shown.each { |m| puts unloaded_line(m) }
        puts dim("  ... +#{hidden} more unloaded") if hidden.positive?
      end

      def unloaded_line(model)
        ctx = model.context_length ? " #{model.context_length.to_i / 1000}K" : ""
        dim("  #{model.id}#{ctx} (not loaded)")
      end

      def model_detail_line(model)
        status = model.ready? ? green("ready") : yellow("not loaded")
        ctx = model.context_length ? " #{model.context_length.to_i / 1000}K context" : ""
        "  #{model.id}#{dim(ctx)} - #{status}"
      end

      def filter_models(models, filter)
        case filter
        when :ready, :loaded then models.select(&:ready?)
        when :unloaded then models.reject(&:ready?)
        else models
        end
      end

      def show_models_with_examples(server, filtered, filter)
        filtered.each do |model|
          puts model_detail_line(model)
          puts "    #{dim(model.code_example)}"
        end

        show_hidden_count(server, filtered, filter)
      end

      def show_hidden_count(server, filtered, filter)
        hidden = server.models.size - filtered.size
        return unless hidden.positive? && filter != :all

        puts dim("  ... and #{hidden} more (use all: true to see)")
      end
    end
  end
end
