terragrunt_conversion: # Perform a conversion of the terraform code to terragrunt
	@$(USE_TERRA_WHICH) ; \
	  $(CLEANUP_TEMPLATES_TERRAFORM)

terragrunt_options: # Suggest some terragrunt options for development
	@$(USE_TERRA_WHICH)
	@echo "TERRAGRUNT_OPTIONS='$${TERRAGRUNT_OPTIONS:-$(TERRAGRUNT_OPTIONS)}'"
	@echo "Example:" ; cat $(ROOT_DIR)/Makefile.d/terragrunt-options.txt

converge: plan apply # Converge the plan
	@$(USE_TERRA_WHICH)
