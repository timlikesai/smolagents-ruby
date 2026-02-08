# Confidence scoring and calibration concern registrations.
module Smolagents
  module Concerns
    Registry.tap do |r|
      # === Confidence ===
      r.register :confidence_calibration,
                 Smolagents::Concerns::Confidence::Calibration,
                 category: :confidence,
                 provides: %i[score_confidence blend_confidence],
                 description: "Base module for confidence calibration with scorer registry"

      r.register :confidence_syntactic,
                 Smolagents::Concerns::Confidence::Syntactic,
                 category: :confidence,
                 provides: [:score],
                 description: "Syntactic confidence scoring based on schema validation"
    end
  end
end
