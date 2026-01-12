# frozen_string_literal: true

module Smolagents
  module MessageRole
    SYSTEM = :system

    USER = :user

    ASSISTANT = :assistant

    TOOL_CALL = :tool_call

    TOOL_RESPONSE = :tool_response

    def self.all
      [SYSTEM, USER, ASSISTANT, TOOL_CALL, TOOL_RESPONSE]
    end

    def self.valid?(role)
      all.include?(role)
    end
  end
end
