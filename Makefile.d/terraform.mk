ROOT_DIR ?= $(PWD)/..
TEMPLATED ?= yes
IS_MONOREPO ?= no
TF_LOG ?= error
IS_TERRAGRUNT ?= no
IS_TERRAMATE ?= no
IS_TERRAFORM ?= no

B2B_ENVIRONMENT_MANIFEST_TEMPLATE ?= $(ROOT_DIR)/config/templates/environment-manifest.template.yaml
B2B_VERSION ?= $$(set -o pipefail; b2b version 2>/dev/null | grep 'Version:' | awk '{ print $$2 }' 2>/dev/null || echo "0.0.0")
B2B_STACK ?= $$(echo $${B2B_STACK:-$$(basename $$PWD)})

TERRAFORM_CMD ?= tf_cmd() { \
	export AWS_PROFILE=$${AWS_PROFILE:-$(AWS_PROFILE)} ; \
	export TF_VAR_iac_version=$${TF_VAR_iac_version:-$$(cat $(ROOT_DIR)/VERSION)}; \
	export TF_VAR_b2b_version=$${TF_VAR_b2b_version:-$(B2B_VERSION)}; \
	export TF_PLUGIN_CACHE_DIR=$${TF_PLUGIN_CACHE_DIR:-~/.terraform.d/plugin-cache}; \
	[ -d "$${TF_PLUGIN_CACHE_DIR}" ] || mkdir -p $${TF_PLUGIN_CACHE_DIR}; \
	terraform $$*; \
	}; tf_cmd
TERRA_CMD ?= $(TERRAFORM_CMD)
include $(ROOT_DIR)/Makefile.d/python.mk

TERRAGRUNT_CMD ?= export TERRAGRUNT_ORIGINAL_DIR=$$PWD; \
	export TF_VAR_iac_version=$${TF_VAR_iac_version:-$$(cat $(ROOT_DIR)/VERSION)}; \
	export TF_VAR_b2b_version=$${TF_VAR_b2b_version:-$(B2B_VERSION)}; \
	export TF_PLUGIN_CACHE_DIR=$${TF_PLUGIN_CACHE_DIR:-~/.terraform.d/plugin-cache}; \
	[ -d $${TF_PLUGIN_CACHE_DIR} ] || mkdir -p $${TF_PLUGIN_CACHE_DIR}; \
	terragrunt run-all --terragrunt-include-external-dependencies --terragrunt-non-interactive --terragrunt-parallelism=1 --terragrunt-download-dir=$${PWD}/.terragrunt
TERRAGRUNT_DOWNLOAD_DIR ?= $${PWD}/.terragrunt
ifeq ("$(IS_TERRAGRUNT)","yes")
	TERRAGRUNT_OPTIONS ?= --terragrunt-log-level=info --terragrunt-debug --terragrunt-non-interactive
	TERRA_CMD := export AWS_PROFILE=$${AWS_PROFILE:-$(AWS_PROFILE)} ; \
	$(TERRAGRUNT_CMD)
else
	TERRAGRUNT_OPTIONS :=
endif

TERRAMATE_EXE ?= terramate
TERRAMATE_CMD ?= export TERRAMATE_ORIGINAL_DIR=$$PWD; \
	export TF_VAR_iac_version=$${TF_VAR_iac_version:-$$(cat $(ROOT_DIR)/VERSION)}; \
	export TF_VAR_b2b_version=$${TF_VAR_b2b_version:-$(B2B_VERSION)}; \
	export TF_PLUGIN_CACHE_DIR=$${TF_PLUGIN_CACHE_DIR:-~/.terraform.d/plugin-cache}; \
	[ -d $${TF_PLUGIN_CACHE_DIR} ] || mkdir -p $${TF_PLUGIN_CACHE_DIR}; \
	$(TERRAMATE_EXE) run --disable-check-gen-code terraform
ifeq ("$(IS_TERRAMATE)","yes")
	TERRAMATE_OPTIONS ?=
	TERRA_CMD := export AWS_PROFILE=$${AWS_PROFILE:-$(AWS_PROFILE)} ; \
	$(TERRAMATE_CMD)
else
	TERRAMATE_OPTIONS :=
endif

include $(ROOT_DIR)/Makefile.d/terraform-macros.mk

.PHONY: backend

ifndef TERRAFORM_MK_INCLUDED
include $(ROOT_DIR)/Makefile.d/terraform-targets.mk

ifeq ("$(IS_TERRAGRUNT)","yes")
include $(ROOT_DIR)/Makefile.d/terraform-terragrunt.mk
endif

ifeq ("$(IS_MONOREPO)","yes")
include $(ROOT_DIR)/Makefile.d/terraform-monorepo.mk
else
include $(ROOT_DIR)/Makefile.d/terraform-classicrepo.mk
endif
TERRAFORM_MK_INCLUDED := yes
endif
# Shell function to reset other environments
TERRAMATE_RESET_OTHER_ENVIRONMENTS_WARNING ?= \
	environment=$$(basename $$PWD) ; \
	echo "WARNING: This will reset generated terraform files for all environments except environment/$$(basename $$(dirname $$PWD))/$$(basename $$PWD)"; \
	[ ! -z "$$SUPPRESS_RESET_OTHER_ENVIRONMENTS_WARNING" ] || { echo 'Press [Enter] to continue ...' ; read x; }
