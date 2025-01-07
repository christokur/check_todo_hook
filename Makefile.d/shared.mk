ROOT_DIR ?= $(PWD)/..
TERRAFORM_TEMPLATE ?= cookiecutter/cloud-services-applications
TERRAGRUNT_TEMPLATE ?= cookiecutter/cloud-services-terragrunt
COOKIECUTTER_TEMPLATE ?= cookiecutter/cloud-services-terramate
IS_MONOREPO ?= no
SHELL := /bin/bash
include $(ROOT_DIR)/Makefile.d/help.mk
.DEFAULT_GOAL := use_cases
include $(ROOT_DIR)/Makefile.d/aws.mk
include $(ROOT_DIR)/Makefile.d/python.mk
include $(ROOT_DIR)/Makefile.d/terraform.mk
#include $(ROOT_DIR)/Makefile.d/lint.mk
include $(ROOT_DIR)/Makefile.d/k8s.mk
include $(ROOT_DIR)/Makefile.d/argocd.mk

.PHONY: help templates use_cases changelog environment
use_cases: help # Show this use cases
	@echo "Typical use case:"
	@echo "  make aws_sso                                      - Prepare credentials"
	@echo "  edit config.toml                                  - Configure the environment"
	@echo "  make environment B2B_OPTIONS='<environment name>' - Create the environment folder"
	@echo "  cd environment/<type>/<environment name>          - Navigate to the environment folder"
	@echo "  make generate                                     - Generate the terramate and/or terraform code"
	@echo "  make init                                         - Install terraform modules"
	@echo "  make stacks                                       - Inspect the list of stacks for the environment"
	@echo "  make converge                                     - Plan and apply the infrastructure stacks in order"
	@echo "  make kubeconfig                                   - Register the k8s cluster with kubectl/ Lens"
	@echo "  make register ARGOCD_USERNAME=<github username>   - Register the k8s cluster with ArgoCD"
	@echo "  make deployment                                   - Initialize deployments for the environment/ k8s cluster"

doctor: # Check the environment
	$(SHELL) $(ROOT_DIR)/bin/doctor.sh

repositories_tag: # Tag the repositories
	@$(USE_TERRA_WHICH)
	@export ROOT_DIR=$(ROOT_DIR); b2b repositories tag --commit --push --requester=b2b $(B2B_OPTIONS)

terraform_repos_tag: # Tag the terraform repositories
	@$(USE_TERRA_WHICH)
	@export ROOT_DIR=$(ROOT_DIR);
		b2b repositories update 'terraform*';
		b2b repositories tag --commit --push --requester=b2b $(B2B_OPTIONS) 'terraform*'

root_dir: # Show the ROOT_DIR
	@echo $(ROOT_DIR)

workspace_dir: # Show the ROOT_DIR
	@echo $$(realpath $(ROOT_DIR)/..)

bootstrap: # Bootstrap the environment
	@ROOT_DIR=$(ROOT_DIR) bash $(ROOT_DIR)/bin/bootstrap.sh
