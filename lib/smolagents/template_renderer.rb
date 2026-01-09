# frozen_string_literal: true

require "liquid"
require "yaml"

module Smolagents
  # Renders prompt templates using the Liquid template engine.
  # Loads YAML template files and renders them with variable substitution.
  #
  # @example Render a template
  #   renderer = TemplateRenderer.new("prompts/code_agent.yaml")
  #   prompt = renderer.render(:system_prompt, tools: tool_collection, custom_instructions: "Be concise")
  #
  # @example Direct template rendering
  #   renderer = TemplateRenderer.from_string("Hello {{name}}!")
  #   result = renderer.render(name: "World")  # => "Hello World!"
  class TemplateRenderer
    # @return [Hash] loaded template sections from YAML
    attr_reader :templates

    # Initialize renderer from a YAML template file.
    #
    # @param template_path [String] path to YAML template file
    def initialize(template_path)
      @template_path = template_path
      @templates = load_templates(template_path)
      @liquid_templates = {}
    end

    # Create renderer from a template string.
    #
    # @param template_string [String] Liquid template string
    # @return [TemplateRenderer] renderer instance
    def self.from_string(template_string)
      renderer = allocate
      renderer.instance_variable_set(:@templates, { default: template_string })
      renderer.instance_variable_set(:@liquid_templates, {})
      renderer.instance_variable_set(:@template_path, nil)
      renderer
    end

    # Render a template section with variables.
    #
    # @param section [Symbol, String] template section name (e.g., :system_prompt, :planning)
    # @param variables [Hash] template variables
    # @return [String] rendered template
    #
    # @example
    #   renderer.render(:system_prompt, tools: tools, authorized_imports: ["json", "math"])
    def render(section = :default, **variables)
      section = section.to_s
      template = get_liquid_template(section)

      # Convert variables to strings (Liquid requires string keys)
      string_vars = stringify_keys(variables)

      # Render template
      template.render(string_vars)
    end

    # Render a nested section (e.g., planning.initial_plan).
    #
    # @param path [String] dot-separated path (e.g., "planning.initial_plan")
    # @param variables [Hash] template variables
    # @return [String] rendered template
    #
    # @example
    #   renderer.render_nested("planning.initial_plan", task: "Find the answer", tools: tools)
    def render_nested(path, **variables)
      keys = path.split(".")
      template_content = keys.reduce(@templates) do |hash, key|
        return nil unless hash.is_a?(Hash)

        hash[key] || hash[key.to_sym]
      end

      raise ArgumentError, "Template path '#{path}' not found" unless template_content

      # Create temporary Liquid template
      liquid_template = Liquid::Template.parse(template_content)
      string_vars = stringify_keys(variables)
      liquid_template.render(string_vars)
    end

    private

    # Load templates from YAML file.
    #
    # @param path [String] path to YAML file
    # @return [Hash] loaded template sections
    def load_templates(path)
      raise ArgumentError, "Template file not found: #{path}" unless File.exist?(path)

      YAML.load_file(path, symbolize_names: false)
    rescue Psych::SyntaxError => e
      raise ArgumentError, "Invalid YAML in template file #{path}: #{e.message}"
    end

    # Get or create Liquid template for a section.
    #
    # @param section [String] section name
    # @return [Liquid::Template] compiled template
    def get_liquid_template(section)
      return @liquid_templates[section] if @liquid_templates.key?(section)

      template_content = @templates[section] || @templates[section.to_sym]
      raise ArgumentError, "Template section '#{section}' not found" unless template_content

      @liquid_templates[section] = Liquid::Template.parse(template_content)
    end

    # Convert hash keys to strings recursively.
    #
    # @param hash [Hash] hash with symbol or string keys
    # @return [Hash] hash with string keys
    def stringify_keys(hash)
      hash.transform_keys(&:to_s).transform_values do |value|
        value.is_a?(Hash) ? stringify_keys(value) : value
      end
    end
  end
end
