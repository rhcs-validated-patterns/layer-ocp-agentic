.DEFAULT_GOAL := help
SHELL := /bin/bash
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TF_DIR := $(ROOT_DIR)/terraform
SCRIPTS := $(ROOT_DIR)/scripts

ARO_HCP_ROOT ?=
ARO_HCP_PROFILE ?=
VP_TERRAFORM_ROSA_ROOT ?=
ROSA_ROOT ?=
ROSA_PROFILE ?=

.PHONY: help fmt lint test cluster.% docs-venv docs-preview docs-serve docs-build

help: ## Show targets
	@grep -E '^[a-zA-Z0-9_.-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-28s %s\n", $$1, $$2}'
	@echo "Cluster operations: make cluster.<name>.<operation>"
	@echo "  init plan apply destroy bootstrap verify"
	@echo "Set ARO_HCP_ROOT (Azure) or VP_TERRAFORM_ROSA_ROOT / ROSA_ROOT (AWS) to refresh platform.json before apply."

cluster.%:
	@CLUSTER_PROFILE=$$(echo "$@" | cut -d'.' -f2); \
	OPERATION=$$(echo "$@" | cut -d'.' -f3-); \
	if [ -z "$$CLUSTER_PROFILE" ] || [ -z "$$OPERATION" ]; then \
		echo "Usage: make cluster.<name>.<operation>" >&2; exit 1; \
	fi; \
	if [ ! -d "$(ROOT_DIR)/clusters/$$CLUSTER_PROFILE" ]; then \
		echo "Missing clusters/$$CLUSTER_PROFILE" >&2; exit 1; \
	fi; \
	ARO_PROF="$(ARO_HCP_PROFILE)"; \
	[ -n "$$ARO_PROF" ] || ARO_PROF=$$CLUSTER_PROFILE; \
	ROSA_PROF="$(ROSA_PROFILE)"; \
	[ -n "$$ROSA_PROF" ] || ROSA_PROF=$$CLUSTER_PROFILE; \
	$(MAKE) -f Makefile.cluster CLUSTER_PROFILE=$$CLUSTER_PROFILE ARO_HCP_ROOT="$(ARO_HCP_ROOT)" ARO_HCP_PROFILE="$$ARO_PROF" VP_TERRAFORM_ROSA_ROOT="$(VP_TERRAFORM_ROSA_ROOT)" ROSA_ROOT="$(ROSA_ROOT)" ROSA_PROFILE="$$ROSA_PROF" $$OPERATION

fmt: ## Format Terraform and shell
	terraform -chdir=$(TF_DIR) fmt -recursive
	terraform -chdir=$(ROOT_DIR)/modules/azure fmt
	terraform -chdir=$(ROOT_DIR)/modules/aws fmt
	@command -v shfmt >/dev/null && shfmt -w -i 2 -ci -bn $(SCRIPTS)/*.sh || true

lint: ## Validate Terraform and shellcheck
	terraform -chdir=$(ROOT_DIR)/modules/azure init -backend=false -input=false
	terraform -chdir=$(ROOT_DIR)/modules/azure validate
	terraform -chdir=$(ROOT_DIR)/modules/aws init -backend=false -input=false
	terraform -chdir=$(ROOT_DIR)/modules/aws validate
	terraform -chdir=$(TF_DIR) init -backend=false -input=false
	terraform -chdir=$(TF_DIR) validate
	@command -v shellcheck >/dev/null && shellcheck -x $(SCRIPTS)/*.sh || true

test: lint ## terraform test + bats
	@if command -v bats >/dev/null; then bats $(ROOT_DIR)/tests/bats; else echo "bats not installed; skipping"; fi

# Documentation (MkDocs Material)
VENV_DOCS ?= .venv-docs
DOCS_MKDOCS := $(VENV_DOCS)/bin/mkdocs
DOCS_PIP := $(VENV_DOCS)/bin/pip

docs-venv: ## Create docs virtualenv and install requirements-docs.txt
	@if ! command -v python3 >/dev/null 2>&1; then \
		echo "Error: python3 is required for documentation preview" >&2; \
		exit 1; \
	fi
	@if [ ! -d "$(VENV_DOCS)" ]; then \
		echo "Creating docs virtualenv at $(VENV_DOCS)..."; \
		python3 -m venv "$(VENV_DOCS)"; \
	fi
	@$(DOCS_PIP) install -q -r requirements-docs.txt
	@echo "Docs dependencies ready"

docs-preview: docs-venv ## Serve docs at http://127.0.0.1:8000/layer-ocp-agentic/
	@echo "Documentation preview: http://127.0.0.1:8000/layer-ocp-agentic/"
	@echo "Press Ctrl+C to stop"
	@$(DOCS_MKDOCS) serve

docs-serve: docs-preview ## Alias for docs-preview

docs-build: docs-venv ## Build documentation site (strict link checking)
	@$(DOCS_MKDOCS) build --strict
	@echo "Documentation built successfully"