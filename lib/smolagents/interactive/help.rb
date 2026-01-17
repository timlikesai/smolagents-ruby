require_relative "help_content"

module Smolagents
  module Interactive
    # Help content for different topics.
    module Help
      extend ColorHelpers
      include HelpContent

      TOPICS = %i[models tools agents discovery builder].freeze

      module_function

      def show(topic = nil)
        case topic&.to_sym
        when :models then show_models
        when :tools then show_tools
        when :agents then show_agents
        when :discovery then show_discovery
        when :builder then show_builder
        when nil then show_general
        else unknown_topic(topic)
        end
      end

      def show_general
        puts bold("Smolagents Help")
        puts
        puts "  #{bold("Smolagents.models")}       - List available models"
        puts "  #{bold("Smolagents.help :builder")} - Builder method distinctions (.tools vs .as vs .with)"
        puts "  #{bold("Smolagents.help :models")}  - Model configuration help"
        puts "  #{bold("Smolagents.help :tools")}   - Working with tools"
        puts "  #{bold("Smolagents.help :agents")}  - Agent patterns"
        puts
        puts section("Quick Start")
        puts QUICK_START
      end

      def show_models
        puts bold("Model Configuration")
        puts
        puts section("Local Servers")
        puts LOCAL_SERVERS_HELP
        puts
        puts section("Cloud Providers")
        puts CLOUD_PROVIDERS_HELP
      end

      def show_tools
        puts bold("Working with Tools")
        puts
        puts section("Built-in Toolkits")
        puts TOOLKITS_HELP
        puts
        puts section("Custom Tools")
        puts CUSTOM_TOOLS_HELP
      end

      def show_agents
        puts bold("Agent Patterns")
        puts
        puts section("One-shot Execution")
        puts ONESHOT_HELP
        puts
        puts section("Reusable Agent")
        puts REUSABLE_HELP
        puts
        puts section("With Event Handlers")
        puts EVENTS_HELP
      end

      def show_discovery
        puts bold("Model Discovery")
        puts
        puts section("Scan for Models")
        puts SCAN_HELP
        puts
        puts section("Custom Endpoints")
        puts ENDPOINTS_HELP
      end

      BUILDER_SECTIONS = [
        ["Overview", :BUILDER_METHODS_HELP],
        [".tools() - Add Tools", :BUILDER_TOOLS_HELP],
        [".as() - Add Persona Only", :BUILDER_AS_HELP],
        [".with() - Convenience Bundle", :BUILDER_WITH_HELP],
        ["Combining Methods", :BUILDER_COMBINING_HELP]
      ].freeze

      def show_builder
        puts bold("Builder Methods: .tools vs .as vs .with")
        BUILDER_SECTIONS.each do |title, const|
          puts
          puts section(title)
          puts const_get(const)
        end
      end

      def unknown_topic(topic)
        puts "Unknown topic: #{topic}"
        puts "Available: #{TOPICS.join(", ")}"
      end
    end
  end
end
