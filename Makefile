ROOT_DIR ?= $(PWD)
AWS_PROFILE ?= cloud-services-prod
IS_MONOREPO ?= yes
include $(ROOT_DIR)/Makefile.d/help.mk
include $(ROOT_DIR)/Makefile.d/pre-commit.mk
include $(ROOT_DIR)/Makefile.d/terraform-macros.mk

.PHONY: help docs

docs: # Generate documentation
	@$(USE_MONOREPO)
	@for d in $(ROOT_DIR)/terraform $(ROOT_DIR)/terraform/modules/*; do \
		if [ -d $$d ] ; then \
			echo $$d; \
			cp -f $(ROOT_DIR)/cookiecutter/Makefile $$d/ ; \
			cd $$d; \
			if [ ! -f Makefile ] ; then \
			  echo "$$d does not have a Makefile" ; \
			  $(TERRAFORM_DOCS_GENERATE); \
			else \
				if [ -z "$$(egrep /Makefile.d/ Makefile 2>/dev/null)" ] ; then \
					echo "$$d does not have a compatible Makefile" ; \
					$(TERRAFORM_DOCS_GENERATE); \
				else \
					make docs; \
				fi; \
			fi; \
			cd $(ROOT_DIR); \
		fi; \
	done
