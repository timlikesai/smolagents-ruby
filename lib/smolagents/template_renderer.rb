# frozen_string_literal: true

require "erb"
require "yaml"

module Smolagents
  # Renders prompt templates using the ERB template engine.
  class TemplateRenderer
    attr_reader :templates

    def initialize(template_path)
      @template_path = template_path
      @templates = load_templates(template_path)
      @erb_templates = {}
    end

    def self.from_string(template_string)
      allocate.tap do |r|
        r.instance_variable_set(:@templates, { default: template_string })
        r.instance_variable_set(:@erb_templates, {})
        r.instance_variable_set(:@template_path, nil)
      end
    end

    def render(section = :default, **variables)
      get_erb_template(section.to_s).result(create_binding(variables))
    end

    def render_nested(path, **variables)
      template_content = path.split(".").reduce(@templates) { |hash, key| hash.is_a?(Hash) ? (hash[key] || hash[key.to_sym]) : nil }
      raise ArgumentError, "Template path '#{path}' not found" unless template_content

      ERB.new(template_content, trim_mode: "-").result(create_binding(variables))
    end

    private

    def load_templates(path)
      raise ArgumentError, "Template file not found: #{path}" unless File.exist?(path)

      YAML.load_file(path, symbolize_names: false)
    rescue Psych::SyntaxError => e
      raise ArgumentError, "Invalid YAML in template file #{path}: #{e.message}"
    end

    def get_erb_template(section)
      @erb_templates[section] ||= begin
        template_content = @templates[section] || @templates[section.to_sym]
        raise ArgumentError, "Template section '#{section}' not found" unless template_content

        ERB.new(template_content, trim_mode: "-")
      end
    end

    # Creates a binding context for ERB template rendering.
    # Variables are accessible as methods, e.g., `<%= variable_name %>`
    # Nested hashes remain as hashes and use hash access syntax, e.g., `<%= user[:name] %>`
    # Uses an explicit context class instead of OpenStruct for security and Ruby 4.0 compatibility.
    def create_binding(variables)
      TemplateContext.new(variables).get_binding
    end
  end

  # Secure template context that exposes variables as methods.
  # Unlike OpenStruct, this only exposes explicitly provided variables
  # and doesn't allow dynamic attribute creation after initialization.
  class TemplateContext
    def initialize(variables)
      @variables = variables.freeze
      variables.each do |key, value|
        define_singleton_method(key) { value }
      end
    end

    def get_binding
      binding
    end

    # Return nil for missing variables (matches OpenStruct behavior for optional template vars)
    # Templates use patterns like `if var && var.method` to handle optional variables.
    # If called with arguments, raise NoMethodError since templates shouldn't call methods with args.
    def method_missing(name, *args, **)
      return nil if args.empty?

      super
    end

    def respond_to_missing?(name, include_private = false)
      @variables.key?(name) || @variables.key?(name.to_s) || super
    end
  end
end
