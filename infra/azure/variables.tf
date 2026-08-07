variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "swedencentral"
}

variable "resource_group_name" {
  type    = string
  default = "rg-mygpt-ai"
}

variable "key_vault_name" {
  type    = string
  default = "kv-mygpt-ai"
}

variable "storage_account_name" {
  type    = string
  default = "stmygptai"
}

variable "log_analytics_name" {
  type    = string
  default = "la-mygpt-ai"
}

variable "app_insights_name" {
  type    = string
  default = "ai-mygpt-appinsights"
}

variable "ai_foundry_name" {
  type    = string
  default = "mygpt-foundry-hub"
}

variable "ai_foundry_project_name" {
  type    = string
  default = "mygpt-foundry"
}

variable "openai_account_name" {
  description = "Azure OpenAI Cognitive Services account name (becomes <name>.openai.azure.com)."
  type        = string
  default     = "mygpt-openai"
}

variable "docintel_account_name" {
  description = "Azure AI Document Intelligence account name (becomes <name>.cognitiveservices.azure.com)."
  type        = string
  default     = "mygpt-docintel"
}

variable "tags" {
  type    = map(string)
  default = { "managed-by" = "terraform" }
}

# The model deployments the myGPT stack uses:
#   gpt-5.6-luna           — chat (LiteLLM model 'gpt-5.6-luna')
#   text-embedding-3-large — RAG embeddings
#   tts-1                  — TTS (OpenAI-compatible /audio/speech)
# Adjust model_name/version to the region's available models if apply fails.
variable "model_deployments" {
  description = "Azure OpenAI model deployments to create (key = deployment name)."
  type = map(object({
    format        = string
    model_name    = string
    model_version = string
    sku           = string
    capacity      = number
  }))
  default = {
    # capacity = rate limit. GlobalStandard maps 1 capacity → 1 RPM / 1k TPM.
    # 3 (default) caused 429 RateLimitError under normal chat+search use;
    # 10 gives ~10 RPM / 10k TPM headroom.
    "gpt-5.6-luna" = {
      format        = "OpenAI"
      model_name    = "gpt-5.6-luna"
      model_version = "2026-07-09"
      sku           = "GlobalStandard"
      capacity      = 10
    }
    # RAG embeddings were rate-limited at capacity 3 (3 RPM / 3k TPM) — the
    # RAG pipeline fires many embedding calls during ingestion. 10 = 10 RPM / 10k TPM.
    "text-embedding-3-large" = {
      format        = "OpenAI"
      model_name    = "text-embedding-3-large"
      model_version = "1"
      sku           = "Standard"
      capacity      = 10
    }
    # Azure exposes the OpenAI TTS model as name "tts" (version 001);
    # the deployment is named "tts-1" so the app can call it as tts-1.
    "tts-1" = {
      format        = "OpenAI"
      model_name    = "tts"
      model_version = "001"
      sku           = "Standard"
      capacity      = 3
    }
    # Higher-quality TTS (used by the app as model "tts-hd").
    "tts-hd" = {
      format        = "OpenAI"
      model_name    = "tts-hd"
      model_version = "001"
      sku           = "Standard"
      capacity      = 1
    }
  }
}
