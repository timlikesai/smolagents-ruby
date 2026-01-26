require_relative "model_display"

module Smolagents
  module Interactive
    # Display formatting for interactive sessions.
    module Display
      extend ColorHelpers
      extend ModelDisplay

      module_function

      def header
        title = "smolagents"
        version = defined?(Smolagents::VERSION) ? " v#{Smolagents::VERSION}" : ""
        Colors.wrap("#{title}#{version}", Colors::BOLD, Colors::BRIGHT_CYAN)
      end

      def getting_started
        puts yellow("No models found. Here's how to get started:")
        puts
        local_getting_started
        cloud_getting_started
      end

      def local_getting_started
        puts section("Local Models")
        puts "  1. Install LM Studio: https://lmstudio.ai"
        puts "  2. Download a model and start the server"
        puts "  3. Run #{bold("Smolagents.models")} to see available models"
        puts
      end

      def cloud_getting_started
        puts section("Cloud APIs")
        puts "  Set an API key environment variable:"
        puts "    export OPENAI_API_KEY=sk-..."
        puts "    export OPENROUTER_API_KEY=sk-or-..."
        puts "    export GROQ_API_KEY=gsk_..."
      end

      def models_section(discovery)
        discovery.local_servers.select(&:available?).each { |s| server_models(s) }
      end

      def search_section
        search_info = Suggestions.current_search_provider
        return unless search_info

        puts section("Search")
        puts search_line(search_info)
        puts
      end

      def search_line(info)
        if info[:provider] == :searxng
          host = info[:url] ? URI.parse(info[:url]).host : "configured"
          "  #{green("✓")} SearXNG (#{dim(host)})"
        else
          "  #{green("✓")} #{info[:name]}"
        end
      end

      def cloud_section(discovery)
        configured = discovery.cloud_providers.select(&:configured?)
        return unless configured.any?

        puts section("Cloud APIs")
        configured.each { |p| puts "  #{green("✓")} #{p.name} (#{dim(p.env_var)})" }
        puts
      end

      def try_it_section(discovery)
        suggestion = Suggestions.generate(discovery)
        return unless suggestion

        puts section("Try it")
        puts dim("  # Using #{suggestion.search_description}")
        suggestion.code.each_line { |line| puts "  #{line}" }
      end

      def models_list(discovery, filter: :ready)
        return getting_started if empty_discovery?(discovery)

        show_filter_hint(filter)
        show_filtered_servers(discovery, filter)
        show_cloud_list(discovery)
      end

      def empty_discovery?(discovery)
        discovery.all_models.empty? && discovery.cloud_providers.none?(&:configured?)
      end

      def show_filter_hint(filter)
        return if filter == :all

        label = filter == :ready ? "ready models" : "#{filter} models"
        puts dim("Showing #{label}. Use Smolagents.models(all: true) to see all.\n")
      end

      def show_filtered_servers(discovery, filter)
        discovery.local_servers.select(&:available?).each do |server|
          filtered = filter_models(server.models, filter)
          next if filtered.empty?

          puts section("#{server.name} (#{server.base_url})")
          show_models_with_examples(server, filtered, filter)
          puts
        end
      end

      def show_cloud_list(discovery)
        configured = discovery.cloud_providers.select(&:configured?)
        return unless configured.any?

        puts section("Cloud Providers")
        configured.each do |p|
          puts "  #{p.name}"
          puts "    #{dim(p.code_example)}"
        end
      end
    end
  end
end
