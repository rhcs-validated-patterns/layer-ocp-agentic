# Point at installer platform.json after make cluster.<profile>.platform
# Path is relative to terraform/ (see Makefile.cluster).
platform_json = "../../validated-pattern-aro-hcp/clusters/public/platform.json"

# llm_backend = "azure"   # default — modules/azure OpenAI + PE
# llm_backend = "none"    # skip LLM Terraform; hand-write agentic.json before bootstrap

openai_model_name    = "gpt-5-mini"
openai_model_version = "2025-08-07"
openai_capacity   = 10