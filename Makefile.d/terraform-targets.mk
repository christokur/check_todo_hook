plan: validate # Calculate terraform.tfplan
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) plan $(TERRAGRUNT_OPTIONS) -out=terraform.tfplan

plan_ci: validate_ci # Calculate terraform.tfplan for CI
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) plan $(TERRAGRUNT_OPTIONS) -no-color -input=false -out=terraform.tfplan

apply: # Apply terraform plan
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) apply $(TERRAGRUNT_OPTIONS) "terraform.tfplan"

apply_ci: # Apply terraform plan
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) apply $(TERRAGRUNT_OPTIONS) -input=false -no-color "terraform.tfplan"

destroy: # Destroy terraform resources
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) destroy $(TERRAGRUNT_OPTIONS)

output: # Show the outputs
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) output $(TERRAGRUNT_OPTIONS)

refresh: # Refresh the state
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) refresh $(TERRAGRUNT_OPTIONS)

check: # Get the dependencies
	[ "yes" == "$(IS_TERRAGRUNT)" ] || { $(TERRA_CMD) fmt $(TERRAGRUNT_OPTIONS) -check || $(TERRA_CMD) fmt $(TERRAGRUNT_OPTIONS) -check -diff; }

validate_ci: # Get the dependencies
	@$(TERRA_CMD) validate $(TERRAGRUNT_OPTIONS) -no-color

validate: # Get the dependencies
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) validate $(TERRAGRUNT_OPTIONS)

# $(TERRAGRUNT_CMD) terragrunt-info 2>/dev/null | jq '.WorkingDir' | sed 's/"//g' | egrep -v $$PWD
working_dir: # Get the working directory
	@if [ "yes" == "$(IS_TERRAGRUNT)" ] ; then \
		if [ -f .terragrunt-working_dirs ] ; then \
		  cat .terragrunt-working_dirs | sort | uniq ; \
		else \
		   make init; \
			if [ -f .terragrunt-working_dirs ] ; then \
			  cat .terragrunt-working_dirs | sort | uniq ; \
			else \
			   echo "ERROR: No .terragrunt-working_dirs!"; \
			   exit 1; \
			fi ; \
		fi ; \
	else \
	  echo $$(realpath $$PWD) ; \
	fi

clean: # Delete all temporary files and folders
	@$(USE_TERRA_WHICH) $$(basename $$PWD)
	@rm -fr .terragrunt .terragrunt-cache .terraform .terraform.lock.hcl *.lock.hcl *.tfplan *.tfstate *.tfvars.json terragrunt-module-* || true
	@[ ! -d stacks ] || { \
	  if [ -f $(ROOT_DIR)/.terramate.lock ] ; then \
		export SHELL="/bin/bash"; \
		source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; \
	    bg_terramate "Terramate is locked by $$(cat $(ROOT_DIR)/.terramate.lock)! NOT cleaning stacks/*"; \
	  else \
		for sd in stacks/* ; do \
			[ ! -d $$sd ] || { cd $$sd; make clean ; rm _terramate* 2>/dev/null ; cd - >/dev/null; }; \
		done ; \
	  fi ; \
	}
	@for tgm in terragrunt-module-*/; do \
		find $$tgm -name "terragrunt*" -exec rm {} \; 2>/dev/null || true ; \
	done ; \
	rm -fr ./terragrunt-module-*/terragrunt.hcl .terragrunt-working_dirs 2>/dev/null || true

debug_ecr: # Debug services module
	@$(USE_TERRA_WHICH)
	export TARGET=ecr-collection; $(DEBUG_SERVICE)

debug_services: # Debug services module
	@$(USE_TERRA_WHICH)
	@export TARGET=services-environment; $(DEBUG_SERVICE)

debug_database: # Debug database module
	@$(USE_TERRA_WHICH)
	@export TARGET=database; $(DEBUG_SERVICE)

debug_applications: # Debug applications module
	@$(USE_TERRA_WHICH)
	@export TARGET=applications-environment; $(DEBUG_SERVICE)

state_pull: # Pull the stack state
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) state pull $(TERRAGRUNT_OPTIONS) > backup.tfstate

state_push: # Push the stack state
	@$(USE_TERRA_WHICH)
	@if [ -z "$(STATE_FILE)" ] ; then \
		echo "Must specify STATE_FILE path!"; \
		exit 1; \
	fi ; \
	$(TERRA_CMD) state push $(TERRAGRUNT_OPTIONS) $(STATE_FILE)


# Targets used to migrate the ecr repository state between environments
ecr_state_pull: # Pull the ecr state
	@$(USE_TERRA_WHICH)
	@echo "$(TERRA_CMD) state pull $(TERRAGRUNT_OPTIONS) --terragrunt-include-dir $(ROOT_DIR)/terragrunt/ecr-repositories > $(STATE_OUT)"
	@$(TERRA_CMD) state pull $(TERRAGRUNT_OPTIONS) --terragrunt-include-dir $(ROOT_DIR)/terragrunt/ecr-repositories > $(STATE_OUT)

ecr_state_push: # Push the ecr state
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) state push $(TERRAGRUNT_OPTIONS) --terragrunt-include-dir $(ROOT_DIR)/terragrunt/ecr-repositories $(STATE_IN)

ecr_state_migrate: # Migrate the entire ecr state file
	@for resource in $$(terraform state list -state=$(STATE_SRC)); do terraform state mv -state=$(STATE_SRC) -state-out=$(STATE_DST) $$resource $$resource; done

ecr_config_enable: # Enable ecr flag
	@if [ -f "$(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml" ]; then \
		sed -ie 's/^flag_ecr_repositories[[:space:]]*=.*$$/flag_ecr_repositories = "true"/g' "$(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml"; \
	fi

ecr_config_disable: # Disable ecr flag
	@if [ -f "$(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml" ]; then \
		sed -ie 's/^flag_ecr_repositories[[:space:]]*=.*$$/flag_ecr_repositories = "false"/g' "$(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml"; \
	fi

# Targets used to migrate the route53 hosted zone state between environments
services_state_pull: # Pull the services state
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) state pull $(TERRAGRUNT_OPTIONS) --terragrunt-include-dir $(ROOT_DIR)/terragrunt/services > $(STATE_OUT)

services_state_push: # Push the services state
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) state push $(TERRAGRUNT_OPTIONS) --terragrunt-include-dir $(ROOT_DIR)/terragrunt/services $(STATE_IN)

route53_state_migrate: # Migrate just the route53 resource
	terraform state mv -state=$(STATE_SRC) -state-out=$(STATE_DST) module.cloud_services.module.cs_app.module.route53[0] module.cloud_services.module.cs_app.module.route53[0]

route53_config_enable: # Enable route53 hosted zone flag
	@if [ -f "$(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml" ]; then \
		sed -ie 's/^flag_hosted_zone[[:space:]]*=.*$$/flag_hosted_zone = "true"/g' "$(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml"; \
	fi

route53_config_disable: #Disable route53 hosted zone flag
	@if [ -f "$(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml" ]; then \
		sed -ie 's/^flag_hosted_zone[[:space:]]*=.*$$/flag_hosted_zone = "false"/g' "$(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml"; \
	fi

NEED_LOCK ?= yes
ifeq ("$(NEED_LOCK)","yes")
lock lock_hcl: # Update the .lock.hcl
	@$(USE_TERRA_WHICH)
	@export TF_REGISTRY_CLIENT_TIMEOUT=60; $(TERRA_CMD) providers lock -platform=linux_amd64 -platform=darwin_amd64

NEED_LOCK := no
endif # need lock

ifeq ("$(TEMPLATED)","yes")
include $(ROOT_DIR)/Makefile.d/terraform-templated.mk

ifeq ("$(IS_TERRAMATE)","yes")
tf_init: get # Initialize the backend, state and plugins with terramate
	@$(USE_TERRA_WHICH)
	@export GOAL="init"; $(TERRAMATE_LOCK); export TF_REGISTRY_CLIENT_TIMEOUT=60; $(TERRA_CMD) init; $(TERRAMATE_UNLOCK)
	@$(TERRAMATE_EXE) fmt

init: tf_init lock # Initialize the backend, state and plugins with terramate

clean_terraform: # Clean the terraform modules
	@$(USE_TERRA_WHICH)
	@find . -name .terraform -exec rm -fr {} \; || true

reinit: clean_terraform init # Reinitialize the terraform modules

.PHONY: stacks dag run-order stacks_order stacks_pre stacks_post
stacks_order:
	@$(TERRAMATE_EXE) experimental run-order 2>/dev/null

stacks_pre:
	@export ENVIRONMENT_PATH=$$(echo $$PWD | sed "s|$$(realpath $$PWD/../..)/||") ; \
		export CONFIG_STACKS_PRE=$(ROOT_DIR)/config/stacks/pre ; \
		[ ! -f $$ENVIRONMENT_PATH/config/stacks/pre ] || export CONFIG_STACKS_PRE=$$ENVIRONMENT_PATH/config/stacks/pre ; \
		[ ! -f ./config/stacks/pre ] || export CONFIG_STACKS_PRE=./config/stacks/pre ; \
		[ ! -f $$CONFIG_STACKS_PRE ] || cat $$CONFIG_STACKS_PRE | while read stack ; do \
			echo /environment/$$ENVIRONMENT_PATH/stacks/$$stack ; \
		done

stacks_post:
	@export ENVIRONMENT_PATH=$$(echo $$PWD | sed "s|$$(realpath $$PWD/../..)/||") ; \
		export CONFIG_STACKS_POST=$(ROOT_DIR)/config/stacks/post ; \
		[ ! -f $$ENVIRONMENT_PATH/config/stacks/post ] || export CONFIG_STACKS_POST=$$ENVIRONMENT_PATH/config/stacks/post ; \
		[ ! -f ./config/stacks/post ] || export CONFIG_STACKS_POST=./config/stacks/post ; \
		[ ! -f  $$CONFIG_STACKS_POST ] || cat $$CONFIG_STACKS_POST | while read stack ; do \
			[ -d stacks/$$stack ] && echo /environment/$$ENVIRONMENT_PATH/stacks/$$stack || true; \
		done

stacks: # Terramate stacks run-order
	@make stacks_pre stacks_order stacks_post

run-order dag: # Terramate DAG or run-order
	@$(USE_TERRA_WHICH)
	@make stacks

plan_stacks: # Plan the stacks
	@$(USE_TERRA_WHICH)
	@export GOAL="plan"; $(TERRAMATE_LOCK); $(TERRAMATE_ITERATE_STACKS); $(TERRAMATE_UNLOCK)

apply_stacks: # Apply the stacks
	@$(USE_TERRA_WHICH)
	@export GOAL="apply"; $(TERRAMATE_LOCK); $(TERRAMATE_ITERATE_STACKS); $(TERRAMATE_UNLOCK)

converge: # Converge the stacks
	@echo IS_TERRAMATE=yes
	@$(USE_TERRA_WHICH)
	@export GOAL="plan apply"; $(TERRAMATE_LOCK); $(TERRAMATE_ITERATE_STACKS); $(TERRAMATE_UNLOCK)

teardown: # Tear down the stacks
	@$(USE_TERRA_WHICH)
	@export GOAL="destroy"; $(TERRAMATE_ITERATE_STACKS_REVERSE)

outputs: # Tear down the stacks
	@$(USE_TERRA_WHICH)
	@export GOAL="output"; $(TERRAMATE_ITERATE_STACKS)

else # Terramate
backend: python_init # Generate the Terraform backend and provider for all accounts. Depends on Python. Enabled when TEMPLATED := yes
	@echo TEMPLATED=$(TEMPLATED)
	@if [ "$(IS_TERRAGRUNT)" == "no" ] ; then \
  		$(EXPAND_TEMPLATES_BACKEND) ; \
	  else \
	    echo "Skipping terraform backend and provider generation for terragrunt" ; \
	  fi

tf_init: get backend # Initialize the backend, state and plugins with templates
	@$(USE_TERRA_WHICH)
	@rm -fr ./terragrunt-module-*/terragrunt.hcl .terragrunt-working_dirs 2>/dev/null || true
	@export TF_REGISTRY_CLIENT_TIMEOUT=60; $(TERRA_CMD) init -upgrade $(TERRAGRUNT_OPTIONS)
	@[ "yes" == "$(IS_TERRAGRUNT)" ] || { $(TERRA_CMD) fmt $(TERRAGRUNT_OPTIONS); }

init: tf_init lock # Initialize the backend, state and plugins with templates

reinit: clean init # Reinitialize the terraform modules

converge: plan apply # Converge the plan
	@echo IS_TERRAMATE=else


endif # Terramate
else # Templated
tf_init: get # Initialize the backend, state and plugins without templates and optionally with terragrunt
	@$(USE_TERRA_WHICH)
	@export TF_REGISTRY_CLIENT_TIMEOUT=60; $(TERRA_CMD) init $(TERRAGRUNT_OPTIONS)
	@[ "yes" == "$(IS_TERRAGRUNT)" ] || { $(TERRA_CMD) fmt $(TERRAGRUNT_OPTIONS); }

init: tf_init lock # Initialize the backend, state and plugins without templates and optionally with terragrunt

reinit: clean init # Reinitialize the terraform modules

endif

ifeq ("$(IS_TERRAMATE)","yes")
tmskip: # Check for terramate skip
	@$(USE_TERRA_WHICH)
	@path=$$PWD ; \
	export ROOT_DIR=$$(readlink -f $(ROOT_DIR)) ; \
	while [ "$$path" != "$$ROOT_DIR" -a "$$path" != "/" -a "$$path" != "" ] ; do \
		if [ -f "$$path/.tmskip" ] ; then \
			echo "terramate_skip found in $$path" ; \
		fi ; \
		path=$$(dirname "$$path") ; \
	done

get: tmskip # Get the dependencies with terramate
	@$(USE_TERRA_WHICH)
	@export TF_REGISTRY_CLIENT_TIMEOUT=60; $(TERRA_CMD) get 2>/dev/null

.PHONY: list metadata globals run-graph run-order run-env unlock tm_unlock force_unlock tm_force_unlock
list: # List the stacks with terramate
	@$(USE_TERRA_WHICH)
	@$(TERRAMATE_EXE) $@

metadata globals run-graph run-env: # Experimental terramate commands
	@$(USE_TERRA_WHICH)
	@$(TERRAMATE_EXE) experimental $@

show: # Show the plan
	@$(USE_TERRA_WHICH)
	@[ ! -d stacks ] || for sd in stacks/* ; do [ ! -d $$sd ] || { cd $$sd; make show ; cd -; }; done
	@$(TERRA_CMD) show $(TERRAGRUNT_OPTIONS) -no-color terraform.tfplan 2>/dev/null

summarize: # Summarize the plan
	@if [ -d stacks ] ; then \
		for sd in stacks/* ; do \
			[ ! -d $$sd ] || { \
				cd $$sd >/dev/null; \
				echo "$$sd:" ; \
				make show 2>&1 | egrep -e '^(Plan:|No changes.)' || { echo 'No plan? No terraform.tfplan? Try "make plan" first ...'; echo $$(basename $$PWD) >>/tmp/unplanned.txt; } ; \
				cd - >/dev/null; \
			}; \
		done ; \
	else \
		make show 2>&1 | egrep -e '^(Plan:|No changes.)' || { echo 'No plan? No terraform.tfplan? Try "make plan" first ...'; echo $$(basename $$PWD) >>/tmp/unplanned.txt; } ; \
	fi

tm_lock: # Lock the terramate stacks
	@$(USE_TERRA_WHICH)
	@$(TERRAMATE_LOCK)

unlock tm_unlock: # Unlock the terramate stacks
	@$(USE_TERRA_WHICH)
	@$(TERRAMATE_UNLOCK)

force_unlock tm_force_unlock: # FORCE Unlock the terramate stacks
	@$(USE_TERRA_WHICH)
	@rm $(ROOT_DIR)/.terramate.lock 2>&1 || true

else # Terramate
get: # Get the dependencies with terraform / terragrunt
	@$(USE_TERRA_WHICH)
	@export TF_REGISTRY_CLIENT_TIMEOUT=60; $(TERRA_CMD) get -update $(TERRAGRUNT_OPTIONS)

show: # Show the plan
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) show $(TERRAGRUNT_OPTIONS) -no-color terraform.tfplan 2>/dev/null

summarize: # Summarize the plan
	@rm /tmp/$$(basename $$PWD)-before_show_hook.txt 2>/dev/null || true
	@make show 2>&1 | egrep -e '^(Plan:|No changes.)' 2>&1 >/tmp/$$(basename $$PWD)-show.txt || { echo 'No plan? No terraform.tfplan? Try "make plan" first ...'; echo $$(basename $$PWD) >>/tmp/unplanned.txt; }
	@if [ -f /tmp/$$(basename $$PWD)-before_show_hook.txt ] ; then \
		while IFS= read -r line1 && IFS= read -r line2 <&3; do \
			echo "$$(basename $$PWD)($$(basename $$line1)):" ; \
			echo "$$line2" ; \
		done < "/tmp/$$(basename $$PWD)-before_show_hook.txt" 3< "/tmp/$$(basename $$PWD)-show.txt" ; \
	else \
		echo MIA /tmp/$$(basename $$PWD)-before_show_hook.txt ; \
		cat /tmp/$$(basename $$PWD)-show.txt ; \
	fi
endif # Terramate

mirror: # Mirror terraform providers
	@$(USE_TERRA_WHICH)
	@export TF_REGISTRY_CLIENT_TIMEOUT=60; $(TERRA_CMD) providers mirror -platform=linux_amd64 -platform=darwin_amd64 ~/.terraform.d/providers

name: # Show environment name
	@echo $(ENVIRONMENT_NAME)

asgci: # Show sts caller identity
	@aws sts get-caller-identity --profile $$AWS_PROFILE

b2b_depl_min_ver:
	@source $(ROOT_DIR)/scripts/b2b_env_gen_min_ver.rc ; \
		b2b_depl_init_min_ver; \
		[ 0 -eq $$? ] || { \
		   echo "ERROR: b2b version is too old to initialize the deployment."; \
		   exit 1; \
		}

deployment deployment_initialize: b2b_depl_min_ver  # Initialize the environment deployment manifest
	@$(USE_TERRA_WHICH)
	@export ROOT_DIR=$(ROOT_DIR); b2b deployment initialize --environment=$(ENVIRONMENT_NAME) $(B2B_OPTIONS)

deployment_create: b2b_depl_min_ver  # Update the environment deployment configuration files for ArgoCD (git)
	@$(USE_TERRA_WHICH)
	@export ROOT_DIR=$(ROOT_DIR); b2b deployment create --environment=$(ENVIRONMENT_NAME) \
		--overwrite-if-exists $(B2B_OPTIONS)

deployment_push: b2b_depl_min_ver  # Update the environment deployment manifest and push to ArgoCD (git)
	@$(USE_TERRA_WHICH)
	@export ROOT_DIR=$(ROOT_DIR); b2b deployment create --environment=$(ENVIRONMENT_NAME) \
		--overwrite-if-exists --commit --push $(B2B_OPTIONS)

environment:  # Create a new environment
	@$(USE_TERRA_WHICH)
	@export ROOT_DIR=$(ROOT_DIR); if [ -z "$(B2B_ENVIRONMENT)" ] ; then \
	  echo "b2b environment initialize <environment name> $(B2B_OPTIONS) or make environment B2B_ENVIRONMENT=<environment name> B2B_OPTIONS=$(B2B_OPTIONS)" ; \
	  else \
	    b2b environment initialize $(B2B_ENVIRONMENT) $(B2B_OPTIONS) ; \
	  fi
