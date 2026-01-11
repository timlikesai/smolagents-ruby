# frozen_string_literal: true

require "erb"
require "ostruct"
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

    def create_binding(variables)
      context = OpenStruct.new(variables) # rubocop:disable Style/OpenStructUse
      context.instance_eval { binding }
    end
  end
end
