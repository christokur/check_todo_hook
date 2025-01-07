ifeq ("$(IS_TERRAMATE)","yes")
fmt:  # Format the IaC
	@$(TERRAMATE_EXE) fmt
	@$(TERRAFORM_CMD) fmt

templates: python_init # Generate the Terraform code. Depends on Python Enabled when TEMPLATED := yes
	@echo TEMPLATED=$(TEMPLATED)
	@[ ! -z "$(ENVIRONMENT_NAME)" ] || { echo "ERROR: Are you in the environment folder?"; exit 1; }
	@$(USE_TERRA_WHICH)
	@source $(ROOT_DIR)/scripts/b2b_env_gen_min_ver.rc ; \
	  source $(ROOT_DIR)/scripts/terramate-reset-other-environments.rc ; \
	  if [ b2b_env_gen_min_ver ] ; then \
	  	b2b environment generate $(B2B_OPTIONS) ; \
	  else \
	  	RC=0 ; \
	  	[ -f .no-generate ] || { $(EXPAND_TEMPLATES_TERRAFORM); set +x; }; \
	  	RC=$$? ; \
	  	[ $$RC -eq 0 ] || exit $$RC ; \
	  	[ -f .no-generate ] || { $(EXPAND_TEMPLATES_COOKIECUTTER); set +x; }; \
	  	RC=$$? ; \
	  	[ $$RC -eq 0 ] || exit $$RC ; \
	  	$(TERRAMATE_EXE) generate ; \
	  	source $(ROOT_DIR)/scripts/terramate-reset-other-environments.rc ; \
		$(TERRAMATE_RESET_OTHER_ENVIRONMENTS_WARNING) ; \
	  	terramate_reset_other_environments; \
	  	make fmt ; \
	  fi

else # IS_TERRAMATE
#fmt:  # Format the IaC
#	@$(TERRAFORM_CMD) fmt

templates: python_init # Generate the Terraform code. Depends on Python Enabled when TEMPLATED := yes
	@echo TEMPLATED=$(TEMPLATED)
	@$(USE_TERRA_WHICH)
	@$(EXPAND_TEMPLATES_TERRAFORM)
	@[ "yes" != "$(IS_TERRAGRUNT)" ] || terragrunt hclfmt
	@$(TERRAFORM_CMD) fmt
	@egrep -Hn -e '(tf_mod_aws_|tg_mod_aws_|version)' *.hcl 2>/dev/null || true
endif

generate: templates # Generate the environment terraform code from templates. Enabled when TEMPLATED := yes

regenerate: clean generate # ReGenerate the environment terraform code from templates. Enabled when TEMPLATED := yes

terraform: generate # Generate the environment terraform code from templates Enabled when TEMPLATED := yes

ungenerate: # Reset the generated terraform code. Enabled when TEMPLATED := yes
	@echo TEMPLATED=$(TEMPLATED)
	@$(USE_TERRAGRUNT)
	@$(USE_TERRAFORM)
	@if [ -f $(ROOT_DIR)/.terramate.lock ] ; then \
		export SHELL="/bin/bash"; \
		source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; \
		bg_terramate "Terramate is locked by $$(cat $(ROOT_DIR)/.terramate.lock)! NOT cleaning generated content!"; \
	else \
		$(UNEXPAND_TEMPLATES_TERRAFORM) ; \
	fi
ifeq ("$(IS_TERRAMATE)","yes")
	@$(USE_TERRA_WHICH)
	@[ ! -d stacks ] || for sd in stacks/* ; do [ ! -d $$sd ] || { [ -d "$(ROOT_DIR)/$(COOKIECUTTER_TEMPLATE)/{{cookiecutter.environment_name}}/stacks/$$sd" ] || { echo "Remove $$sd"; rm -fr $$sd; } ; }; done
endif
