# Azure AI Foundry + OpenAI models — Terraform

Provisions the Azure AI infrastructure the myGPT stack needs, in the
subscription of the authenticated `az` session:

- **AI Foundry** hub + project (`azurerm_ai_foundry`, `azurerm_ai_foundry_project`)
  with the supporting Key Vault, Storage, Log Analytics + App Insights.
- **Azure OpenAI account** (`azurerm_cognitive_account`, kind `OpenAI`) at
  `<name>.openai.azure.com`.
- **Model deployments** (`azurerm_cognitive_deployment`): `gpt-5.6-luna` (chat),
  `text-embedding-3-large` (RAG embeddings), `tts-1` (TTS).

## Use

```bash
az login                      # must be authenticated (no keys in this repo)
cp terraform.tfvars.example terraform.tfvars   # optional overrides
terraform init
terraform plan                # review before creating resources
terraform apply               # creates the AI stack + model deployments
terraform output              # endpoints / deployment names
```

## Variables

All names and the model list are variables (see `variables.tf`) — nothing is
hardcoded. Model `model_version` values must match what's available in the
chosen region; adjust in `terraform.tfvars` if a deployment fails.

## Notes

- Credentials are never stored here — the provider authenticates via
  `az login` (Azure CLI).
- The stack deploys to this subscription. The running app points at this
  account: `values.secrets.yaml` sets `AZURE_AI_API_BASE` /
  `AZURE_AI_API_KEY` to `mygpt-openai` (and `AUDIO_TTS_*` for TTS, plus
  `mygpt-docintel` for document parsing).
