module Smolagents
  # LLM model implementations for various providers.
  #
  # The Models module contains all language model implementations that can be
  # used with Smolagents agents. Each model class provides a consistent interface
  # for generating text responses, with provider-specific features and optimizations.
  #
  # All models inherit from {Models::Model} and implement the {Models::Model#generate}
  # method for chat completion. Streaming responses are available via
  # {Models::Model#generate_stream}.
  #
  # @example Using OpenAI-compatible models (local inference)
  #   model = Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")
  #   response = model.generate([ChatMessage.user("Hello!")])
  #
  # @example Using Anthropic Claude
  #   model = Smolagents::AnthropicModel.new(
  #     model_id: "claude-opus-4-5-20251101",
  #     api_key: ENV["ANTHROPIC_API_KEY"]
  #   )
  #
  # @example Using the model router (LiteLLM style)
  #   model = Smolagents::LiteLLMModel.new(model_id: "anthropic/claude-sonnet-4-5-20251101")
  #
  # @example Using the ModelBuilder DSL
  #   model = Smolagents.model(:lm_studio)
  #     .id("gemma-3n-e4b-it-q8_0")
  #     .temperature(0.7)
  #     .with_retry(max_attempts: 3)
  #     .build
  #
  # ## Available Models
  #
  # - {Models::Model} - Abstract base class
  # - {Models::OpenAIModel} - OpenAI and compatible APIs (LM Studio, Ollama, llama.cpp, vLLM)
  # - {Models::AnthropicModel} - Anthropic Claude APIs
  # - {Models::LiteLLMModel} - Multi-provider router with "provider/model" format
  #
  # @see Models::Model Base class with interface documentation
  # @see Builders::ModelBuilder DSL for configuring models
  module Models
  end
end

require_relative "models/model"
require_relative "models/openai_model"
require_relative "models/anthropic_model"
require_relative "models/litellm_model"

module Smolagents
  # Re-export model classes at Smolagents level for backward compatibility.
  # These allow using Smolagents::OpenAIModel instead of Smolagents::Models::OpenAIModel.

  # @see Models::Model
  Model = Models::Model

  # @see Models::OpenAIModel
  OpenAIModel = Models::OpenAIModel

  # @see Models::AnthropicModel
  AnthropicModel = Models::AnthropicModel

  # @see Models::LiteLLMModel
  LiteLLMModel = Models::LiteLLMModel
end
