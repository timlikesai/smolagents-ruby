# frozen_string_literal: true

require "liquid"
require "yaml"

module Smolagents
  # Renders prompt templates using the Liquid template engine.
  class TemplateRenderer
    attr_reader :templates

    def initialize(template_path)
      @template_path = template_path
      @templates = load_templates(template_path)
      @liquid_templates = {}
    end

    def self.from_string(template_string)
      allocate.tap do |r|
        r.instance_variable_set(:@templates, { default: template_string })
        r.instance_variable_set(:@liquid_templates, {})
        r.instance_variable_set(:@template_path, nil)
      end
    end

    def render(section = :default, **variables)
      get_liquid_template(section.to_s).render(stringify_keys(variables))
    end

    def render_nested(path, **variables)
      template_content = path.split(".").reduce(@templates) { |hash, key| hash.is_a?(Hash) ? (hash[key] || hash[key.to_sym]) : nil }
      raise ArgumentError, "Template path '#{path}' not found" unless template_content

      Liquid::Template.parse(template_content).render(stringify_keys(variables))
    end

    private

    def load_templates(path)
      raise ArgumentError, "Template file not found: #{path}" unless File.exist?(path)

      YAML.load_file(path, symbolize_names: false)
    rescue Psych::SyntaxError => e
      raise ArgumentError, "Invalid YAML in template file #{path}: #{e.message}"
    end

    def get_liquid_template(section)
      @liquid_templates[section] ||= begin
        template_content = @templates[section] || @templates[section.to_sym]
        raise ArgumentError, "Template section '#{section}' not found" unless template_content

        Liquid::Template.parse(template_content)
      end
    end

    def stringify_keys(hash)
      hash.transform_keys(&:to_s).transform_values { |v| v.is_a?(Hash) ? stringify_keys(v) : v }
    end
  end
end
