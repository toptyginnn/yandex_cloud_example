# ──────────────────────────────────────────────────────────────────────────────
# Makefile – OpenTofu operations for Yandex Cloud infrastructure
# ──────────────────────────────────────────────────────────────────────────────
#
# Usage:
#   make init   ENV=stage
#   make plan   ENV=stage
#   make apply  ENV=stage
#   make destroy ENV=prod
#   make output ENV=infra
#   make fmt
#   make validate ENV=stage
#
# Valid ENV values: infra, stage, prod
# ──────────────────────────────────────────────────────────────────────────────

SHELL := /bin/bash
.DEFAULT_GOAL := help

# ── Validate ENV parameter ───────────────────────────────────────────────────
VALID_ENVS := infra stage prod
ENV_DIR    := environments/$(ENV)

define check_env
	@if [ -z "$(ENV)" ]; then \
		echo "ERROR: ENV is required. Usage: make $(1) ENV=<infra|stage|prod>"; \
		exit 1; \
	fi
	@if ! echo "$(VALID_ENVS)" | grep -qw "$(ENV)"; then \
		echo "ERROR: Invalid ENV='$(ENV)'. Must be one of: $(VALID_ENVS)"; \
		exit 1; \
	fi
	@if [ ! -d "$(ENV_DIR)" ]; then \
		echo "ERROR: Directory $(ENV_DIR) does not exist"; \
		exit 1; \
	fi
endef

# ── Tofu binary (auto-detect tofu vs terraform) ─────────────────────────────
TOFU := $(shell command -v tofu 2>/dev/null || command -v terraform 2>/dev/null)

# ── Ansible binary ───────────────────────────────────────────────────────────
ANSIBLE_PLAYBOOK := $(shell command -v ansible-playbook 2>/dev/null)
ANSIBLE_DIR      := ../ansible

# ═════════════════════════════════════════════════════════════════════════════
# Targets
# ═════════════════════════════════════════════════════════════════════════════

.PHONY: help init plan apply destroy output fmt validate clean console refresh import state-list
.PHONY: k8s-apps k8s-apps-stage k8s-apps-prod kubeconfig

## help: Show this help message
help:
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║           Infrastructure Management — Makefile              ║"
	@echo "╚══════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "  Usage:  make <target> ENV=<infra|stage|prod>"
	@echo ""
	@echo "  Terraform targets:"
	@echo "    init       Initialize tofu working directory"
	@echo "    plan       Generate and show an execution plan"
	@echo "    apply      Apply the changes (with auto-approve)"
	@echo "    destroy    Destroy all managed infrastructure"
	@echo "    output     Show all outputs"
	@echo "    validate   Validate configuration files"
	@echo "    fmt        Format all .tf files (no ENV needed)"
	@echo "    console    Open interactive tofu console"
	@echo "    refresh    Refresh state from real infrastructure"
	@echo "    import     Import existing resource (RESOURCE, ID required)"
	@echo "    state-list List all resources in state"
	@echo "    clean      Remove .terraform directories and lock files"
	@echo ""
	@echo "  Kubernetes app targets (Ansible, run after TF apply + kubeconfig):"
	@echo "    kubeconfig         Fetch kubeconfig for ENV cluster"
	@echo "    k8s-apps-stage     Deploy K8s apps to stage via Ansible"
	@echo "    k8s-apps-prod      Deploy K8s apps to prod via Ansible"
	@echo ""
	@echo "  Deployment order:"
	@echo "    1. make init   ENV=stage && make apply ENV=stage"
	@echo "    2. make kubeconfig ENV=stage"
	@echo "    3. make k8s-apps-stage"
	@echo ""
	@echo "  Examples:"
	@echo "    make init ENV=infra"
	@echo "    make plan ENV=stage"
	@echo "    make apply ENV=prod"
	@echo "    make destroy ENV=stage"
	@echo ""

## init: Initialize tofu (download providers, configure backend)
init:
	$(call check_env,init)
	@echo "══════ Initializing $(ENV) ══════"
	cd $(ENV_DIR) && $(TOFU) init -upgrade

## plan: Generate execution plan and save to file
plan:
	$(call check_env,plan)
	@echo "══════ Planning $(ENV) ══════"
	cd $(ENV_DIR) && $(TOFU) plan -out=$(ENV).tfplan

## apply: Apply saved plan or auto-approve
apply:
	$(call check_env,apply)
	@echo "══════ Applying $(ENV) ══════"
	@if [ -f "$(ENV_DIR)/$(ENV).tfplan" ]; then \
		cd $(ENV_DIR) && $(TOFU) apply $(ENV).tfplan; \
	else \
		echo "No saved plan found. Running plan + apply with auto-approve..."; \
		cd $(ENV_DIR) && $(TOFU) apply -auto-approve; \
	fi

## destroy: Destroy all resources in environment
destroy:
	$(call check_env,destroy)
	@echo "══════ ⚠️  Destroying $(ENV) ══════"
	@echo "WARNING: This will destroy ALL resources in $(ENV)!"
	@read -p "Type '$(ENV)' to confirm: " confirm && \
		if [ "$$confirm" != "$(ENV)" ]; then \
			echo "Aborted."; exit 1; \
		fi
	cd $(ENV_DIR) && $(TOFU) destroy -auto-approve

## output: Show all outputs
output:
	$(call check_env,output)
	@echo "══════ Outputs for $(ENV) ══════"
	cd $(ENV_DIR) && $(TOFU) output

## validate: Validate configuration
validate:
	$(call check_env,validate)
	@echo "══════ Validating $(ENV) ══════"
	cd $(ENV_DIR) && $(TOFU) validate

## fmt: Format all .tf files recursively (no ENV needed)
fmt:
	@echo "══════ Formatting all .tf files ══════"
	$(TOFU) fmt -recursive .

## console: Interactive tofu console
console:
	$(call check_env,console)
	cd $(ENV_DIR) && $(TOFU) console

## refresh: Refresh state
refresh:
	$(call check_env,refresh)
	@echo "══════ Refreshing state for $(ENV) ══════"
	cd $(ENV_DIR) && $(TOFU) refresh

## import: Import existing resource into state
## Usage: make import ENV=stage RESOURCE=module.vpc.yandex_vpc_network.this ID=abc123
import:
	$(call check_env,import)
	@if [ -z "$(RESOURCE)" ] || [ -z "$(ID)" ]; then \
		echo "ERROR: RESOURCE and ID are required."; \
		echo "Usage: make import ENV=stage RESOURCE=<resource_address> ID=<resource_id>"; \
		exit 1; \
	fi
	@echo "══════ Importing $(RESOURCE) = $(ID) into $(ENV) ══════"
	cd $(ENV_DIR) && $(TOFU) import $(RESOURCE) $(ID)

## state-list: List all resources in state
state-list:
	$(call check_env,state-list)
	cd $(ENV_DIR) && $(TOFU) state list

## clean: Remove .terraform dirs and plan files
clean:
	$(call check_env,clean)
	@echo "══════ Cleaning $(ENV) ══════"
	rm -rf $(ENV_DIR)/.terraform
	rm -f $(ENV_DIR)/.terraform.lock.hcl
	rm -f $(ENV_DIR)/$(ENV).tfplan

## clean-all: Remove .terraform dirs from ALL environments (no ENV needed)
clean-all:
	@echo "══════ Cleaning all environments ══════"
	@for env in $(VALID_ENVS); do \
		echo "  Cleaning $$env..."; \
		rm -rf environments/$$env/.terraform; \
		rm -f environments/$$env/.terraform.lock.hcl; \
		rm -f environments/$$env/$$env.tfplan; \
	done
	@echo "Done."

# ═════════════════════════════════════════════════════════════════════════════
# Kubernetes app targets (Ansible)
# ═════════════════════════════════════════════════════════════════════════════

## kubeconfig: Fetch kubeconfig for ENV cluster (requires yc CLI)
kubeconfig:
	$(call check_env,kubeconfig)
	@echo "══════ Fetching kubeconfig for $(ENV) ══════"
	@CLUSTER_ID=$$(cd $(ENV_DIR) && $(TOFU) output -raw k8s_cluster_id) && \
		echo "Cluster ID: $$CLUSTER_ID" && \
		yc managed-kubernetes cluster get-credentials --id $$CLUSTER_ID --internal --force
	@echo "Kubeconfig updated. Context: yc-$(ENV)-cluster"

## k8s-apps-stage: Deploy K8s applications to stage via Ansible
k8s-apps-stage:
	@echo "══════ Deploying K8s apps to stage ══════"
	cd $(ANSIBLE_DIR) && $(ANSIBLE_PLAYBOOK) playbooks/k8s-apps-stage.yml

## k8s-apps-prod: Deploy K8s applications to prod via Ansible
k8s-apps-prod:
	@echo "══════ Deploying K8s apps to prod ══════"
	cd $(ANSIBLE_DIR) && $(ANSIBLE_PLAYBOOK) playbooks/k8s-apps-prod.yml

# ── Convenience aliases ──────────────────────────────────────────────────────
.PHONY: infra-init infra-plan infra-apply stage-init stage-plan stage-apply prod-init prod-plan prod-apply

infra-init:
	@$(MAKE) init ENV=infra

infra-plan:
	@$(MAKE) plan ENV=infra

infra-apply:
	@$(MAKE) apply ENV=infra

stage-init:
	@$(MAKE) init ENV=stage

stage-plan:
	@$(MAKE) plan ENV=stage

stage-apply:
	@$(MAKE) apply ENV=stage

prod-init:
	@$(MAKE) init ENV=prod

prod-plan:
	@$(MAKE) plan ENV=prod

prod-apply:
	@$(MAKE) apply ENV=prod

# ── Full deployment (apply in correct order) ─────────────────────────────────
.PHONY: deploy-all

## deploy-all: Apply infra → stage → prod in order (TF only, run k8s-apps-* separately)
deploy-all:
	@echo "══════ Full deployment: infra → stage → prod ══════"
	@$(MAKE) init ENV=infra
	@$(MAKE) apply ENV=infra
	@echo ""
	@$(MAKE) init ENV=stage
	@$(MAKE) apply ENV=stage
	@echo ""
	@$(MAKE) init ENV=prod
	@$(MAKE) apply ENV=prod
	@echo ""
	@echo "══════ Terraform complete. Next steps: ══════"
	@echo "  make kubeconfig ENV=stage && make k8s-apps-stage"
	@echo "  make kubeconfig ENV=prod  && make k8s-apps-prod"
	@echo "══════════════════════════════════════════════"
