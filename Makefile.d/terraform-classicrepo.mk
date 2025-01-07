ifeq ("$(IS_TERRAFORM)","yes")
ifeq ("$(IS_TERRAMATE)","yes")
else
fmt: # Format terraform code
	@$(USE_CLASSICREPO)
	@$(TERRAFORM_CMD) fmt
	@[ "yes" != "$(IS_TERRAGRUNT)" ] || { $(TERRAGRUNT_CMD) hclfmt || true; }

endif

docs: fmt # Generate documentation
	@$(USE_CLASSICREPO)
	@$(TERRAFORM_DOCS_GENERATE)

converge: plan apply # Converge the plan

endif
