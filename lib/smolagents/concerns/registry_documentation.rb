module Smolagents
  module Concerns
    module Registry
      # Documentation generation for the concern registry.
      #
      # Provides markdown documentation generation for introspection and
      # auto-generated documentation of registered concerns.
      #
      # @see Registry For concern registration and querying
      module Documentation
        # Generates markdown documentation for all concerns.
        # @return [String] Formatted documentation
        def documentation
          by_category.map do |category, concern_infos|
            category_doc(category, concern_infos)
          end.join("\n---\n\n")
        end

        private

        def category_doc(category, concern_infos)
          <<~DOC
            ## #{titleize(category)}

            #{concern_infos.map { concern_doc(it) }.join("\n\n")}
          DOC
        end

        def concern_doc(info)
          deps = info.dependencies.any? ? info.dependencies.join(", ") : "None"
          provides = info.provides.any? ? info.provides.join(", ") : "None"
          <<~DOC.strip
            ### #{info.name}
            #{info.description || "No description"}

            **Module:** `#{info.module_path}`
            **Provides:** #{provides}
            **Dependencies:** #{deps}
          DOC
        end

        def titleize(sym)
          sym.to_s.split("_").map(&:capitalize).join(" ")
        end
      end
    end
  end
end
