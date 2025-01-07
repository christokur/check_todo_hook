define SNAKE
export SHELL="/bin/bash"; \
bash -c 'source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; bg_snake " 🐍 "'
endef

define RUBY
export SHELL="/bin/bash"; \
bash -c 'source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; bg_ruby " 💎 "'
endef

define USE_TERRAFORM
export SHELL="/bin/bash"; \
source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; bg_terraform " Terraform -- $@ "
endef

define USE_TERRAGRUNT
export SHELL="/bin/bash"; \
source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; bg_terragrunt " Terragrunt -- $@ "
endef

define USE_TERRAMATE
export SHELL="/bin/bash"; \
source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; bg_terramate " Terramate -- $@ "
endef

define USE_MONOREPO
export SHELL="/bin/bash"; \
bash -c 'source $(ROOT_DIR)/cicd/rc/ansi-colors.rc; bg_monorepo " monorepo -- $@ "'
endef

define USE_CLASSICREPO
export SHELL="/bin/bash"; \
bash -c 'source $(ROOT_DIR)/cicd/rc/ansi-colors.rc; bg_classicrepo " classicrepo -- $@ "'
endef

BACKUP_MAKEFILE = cp Makefile Makefile.bak || true
RESTORE_MAKEFILE = [ -f Makefile.bak -a -f Makefile ] && { diff Makefile.bak Makefile 2>&1 >/dev/null || true; }; [ 0 -eq $$? ] || mv -f Makefile.bak Makefile

EXPAND_TEMPLATES_BACKEND = export SHELL="/bin/bash"; \
export TF_VAR_iac_version=$${TF_VAR_iac_version:-$$(cat $(ROOT_DIR)/VERSION)}; \
export TF_VAR_b2b_version=$${TF_VAR_b2b_version:-$(B2B_VERSION)}; \
for tpl in $(ROOT_DIR)/$(TERRAFORM_TEMPLATE)/{backend,providers}.tf.jinja2; do \
	$(PYTHON) $(ROOT_DIR)/bin/template-expander.py -i $$tpl -o ./$$(basename $${tpl//.jinja2/}) -s .:$$(dirname $$tpl):$(ROOT_DIR)/cookiecutter -d $(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml || exit $$?; \
done

EXPAND_TEMPLATES_TERRAFORM = export SHELL="/bin/bash"; \
export TF_VAR_iac_version=$${TF_VAR_iac_version:-$$(cat $(ROOT_DIR)/VERSION)}; \
export TF_VAR_b2b_version=$${TF_VAR_b2b_version:-$(B2B_VERSION)}; \
$(BACKUP_MAKEFILE) ; \
for tpl in $(ROOT_DIR)/$(TERRAFORM_TEMPLATE)/*.jinja2; do \
	echo $$tpl ; \
	RC=0 ; \
	[ -z "$$DEBUG_TEMPLATES" ] || export LOG_LEVEL=$${LOG_LEVEL:-INFO}; \
	[ -z "$$DEBUG_TEMPLATES" ] || echo "$(PYTHON) $(ROOT_DIR)/bin/template-expander.py -i $$tpl -o ./$$(basename $${tpl//.jinja2/}) -s .:$$(dirname $$tpl):$$(dirname $$tpl)/.. -d $(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml"; \
	$(PYTHON) $(ROOT_DIR)/bin/template-expander.py -i $$tpl -o ./$$(basename $${tpl//.jinja2/}) -s .:$$(dirname $$tpl):$(ROOT_DIR)/cookiecutter -d $(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml || RC=$$?; \
	test 0 -eq $$RC || { $(RESTORE_MAKEFILE) ; exit $$RC; } ; \
done ; \
$(RESTORE_MAKEFILE)

UNEXPAND_TEMPLATES_TERRAFORM = export SHELL="/bin/bash"; \
export TF_VAR_iac_version=$${TF_VAR_iac_version:-$$(cat $(ROOT_DIR)/VERSION)}; \
export TF_VAR_b2b_version=$${TF_VAR_b2b_version:-$(B2B_VERSION)}; \
$(BACKUP_MAKEFILE) ; \
for tpl in $(ROOT_DIR)/$(TERRAFORM_TEMPLATE)/*.jinja2; do \
	echo $$tpl ; \
	RC=0 ; \
	[ -z "$$DEBUG_TEMPLATES" ] || echo "rm ./$$(basename $${tpl//.jinja2/})"; \
	rm ./$$(basename $${tpl//.jinja2/}) 2>/dev/null || true; \
	test 0 -eq $$RC || { $(RESTORE_MAKEFILE) ; exit $$RC; } ; \
done ; \
$(RESTORE_MAKEFILE)

# Cookiecutter
EXPAND_TEMPLATES_COOKIECUTTER = export SHELL="/bin/bash"; \
export TF_VAR_iac_version=$${TF_VAR_iac_version:-$$(cat $(ROOT_DIR)/VERSION)}; \
export TF_VAR_b2b_version=$${TF_VAR_b2b_version:-$(B2B_VERSION)}; \
$(BACKUP_MAKEFILE) ; \
RC=0 ; \
$(PYTHON) $(ROOT_DIR)/bin/template-expander.py --version || RC=$$?; \
tpl=$(ROOT_DIR)/$(TERRAFORM_TEMPLATE)/locals.hcl.jinja2; \
[ -z "$$DEBUG_TEMPLATES" ] || echo $(PYTHON) $(ROOT_DIR)/bin/template-expander.py -i $$tpl -o ./$$(basename $${tpl//.jinja2/}) -s .:$$(dirname $$tpl):$(ROOT_DIR)/cookiecutter -d $(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml ; \
$(PYTHON) $(ROOT_DIR)/bin/template-expander.py -i $$tpl -o ./$$(basename $${tpl//.jinja2/}) -s .:$$(dirname $$tpl):$(ROOT_DIR)/cookiecutter -d $(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml || RC=$$?; \
[ -z "$$DEBUG_TEMPLATES" ] || echo $(PYTHON) $(ROOT_DIR)/bin/template-expander.py -s $(ROOT_DIR)/cookiecutter -c $(ROOT_DIR)/$(COOKIECUTTER_TEMPLATE) -t .. -l locals.hcl -d $(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml --overwrite ; \
[ 0 -ne $$RC ] || $(PYTHON) $(ROOT_DIR)/bin/template-expander.py -s $(ROOT_DIR)/cookiecutter -c $(ROOT_DIR)/$(COOKIECUTTER_TEMPLATE) -t .. -l locals.hcl -d $(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml --overwrite || RC=$$?; \
$(RESTORE_MAKEFILE) ; \
[ 0 -eq $$RC ]|| { exit $$RC; }

USE_TERRA_WHICH = terra_which() { if [ "$(IS_TERRAMATE)" == "yes" ] ; then \
	$(USE_TERRAMATE) $$*; \
else \
	if [ "$(IS_TERRAGRUNT)" == "no" ] ; then \
		$(USE_TERRAFORM) $$*; \
	else \
		$(USE_TERRAGRUNT) $$*; \
	fi; \
fi ; } ; terra_which

CLEANUP_TEMPLATES_TERRAFORM = export SHELL="/bin/bash"; \
export PYTHON=$(PYTHON) ; \
export ROOT_DIR=$(ROOT_DIR) ; \
export TERRAFORM_TEMPLATE=$(TERRAFORM_TEMPLATE) ; \
export ENVIRONMENT_NAME=$(ENVIRONMENT_NAME) ; \
bash $(ROOT_DIR)/bin/terragrunt-conversion.sh

TERRAFORM_DOCS_GENERATE = export SHELL="/bin/bash"; \
export TERRAGRUNT_ORIGINAL_DIR=$$PWD; \
export ROOT_DIR=$(ROOT_DIR) ; \
export IS_TERRAGRUNT=$(IS_TERRAGRUNT) ; \
export ENVIRONMENT_NAME=$(ENVIRONMENT_NAME) ; \
export LAST_MAKEFILE=$(lastword $(MAKEFILE_LIST)) ; \
bash $(ROOT_DIR)/bin/terraform-docs-generate.sh

DEBUG_SERVICE = export SERVICE=$$(make working_dir | grep $$TARGET 2>/dev/null | head -1) ; \
	if [ ! -z "$$SERVICE" ] ; then \
		if [ -d "$$SERVICE" ] ; then \
			pushd $$SERVICE; \
			source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; \
			bg_terraform "You can debug terraform here e.g.: terraform plan --var-file=terragrunt-debug.tfvars.json -out=terraform.tfplan"; \
			bash -l; \
		else \
			echo "No such directory: $$SERVICE" ; \
			ls -ald $$SERVICE ; \
		fi ; \
	fi

TERRAMATE_ITERATE_STACKS = \
pwd ; \
export SHELL="/bin/bash"; \
source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; \
export RD=$$(echo $$(realpath $$PWD) | sed "s|$$(realpath $(ROOT_DIR))||") ; \
export DEBUG_STACKS=$${DEBUG_STACKS:-$(DEBUG_STACKS)} ; \
if [ -d stacks ] ; then \
	make stacks >/tmp/$$(basename $$RD).stacks ; \
	for stack in $$(cat /tmp/$$(basename $$RD).stacks) ; do \
		[ ! -f .stop ] || { bg_terramate ".stop file found!"; break; }; \
		SD=$$(echo $$stack | sed "s|$$RD/||") ; \
		[ -d $$SD ] || export SD=stacks/$$(basename $$stack); \
		[ -z "$$DEBUG_STACKS" ] || { pwd; echo SD=$$SD; bg_terramate "press ENTER"; echo read x; }; \
		[ -d $$SD ] && { \
			cd $$SD ; \
			export B2B_STACK=$$(basename $$SD) ; \
			bg_terramate $$PWD ; \
			make $${GOAL} ; \
			RC=$$? ; \
			[ 0 -eq $$RC -o ! -z "$$IGNORE_RETURN_CODES" ] || { bg_terramate "Error in stack $$SD"; break; }; \
			[ -z "$$DEBUG_STACKS" ] || { pwd; bg_terramate "Inspect stack and press ENTER"; echo read x; }; \
			cd - >/dev/null ; \
		} || { echo "$$SD does not exist!"; pwd; exit 5; } ; \
	done ; \
else \
	bg_terramate $$PWD ; \
	make $${GOAL} ; \
	RC=$$? ; \
	[ 0 -eq $$RC -o ! -z "$$IGNORE_RETURN_CODES" ] || { bg_terramate "Error in stack $$SD"; }; \
	[ -z "$$DEBUG_STACKS" ] || { bg_terramate "Inspect stack and press ENTER"; read x; }; \
fi

TERRAMATE_ITERATE_STACKS_REVERSE = \
pwd ; \
export SHELL="/bin/bash"; \
source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; \
export RD=$$(echo $$(realpath $$PWD) | sed "s|$$(realpath $(ROOT_DIR))||") ; \
export DEBUG_STACKS=$${DEBUG_STACKS:-$(DEBUG_STACKS)} ; \
if [ -d stacks ] ; then \
	make stacks_order | tac >/tmp/$$(basename $$RD).stacks ; \
	for stack in $$(cat /tmp/$$(basename $$RD).stacks) ; do \
		[ ! -f .stop ] || { bg_terramate ".stop file found!"; break; }; \
		SD=$$(echo $$stack | sed "s|$$RD/||") ; \
		[ -d $$SD ] || export SD=stacks/$$(basename $$stack); \
		[ -d $$SD ] && { \
			cd $$SD ; \
			export B2B_STACK=$$(basename $$SD) ; \
			bg_terramate $$PWD ; \
			terraform $${GOAL} $(AUTO_APPROVE); \
			RC=$$? ; \
			[ 0 -eq $$RC -o ! -z "$$IGNORE_RETURN_CODES" ] || { bg_terramate "Error in stack $$SD"; break; }; \
			[ -z "$$DEBUG_STACKS" ] || { bg_terramate "Inspect stack and press ENTER"; read x; }; \
			cd - >/dev/null ; \
		} || { echo "$$SD does not exist!"; pwd; exit 5; } ; \
	done ; \
else \
	bg_terramate $$PWD ; \
	terraform $${GOAL} $(AUTO_APPROVE); \
	RC=$$? ; \
	[ 0 -eq $$RC -o ! -z "$$IGNORE_RETURN_CODES" ] || { bg_terramate "Error in stack $$SD"; }; \
	[ -z "$$DEBUG_STACKS" ] || { bg_terramate "Inspect stack and press ENTER"; read x; }; \
fi

TERRAMATE_LOCK = \
export SHELL="/bin/bash"; \
source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; \
if [ -f $(ROOT_DIR)/.terramate.lock -a ! -z "$$(cat $(ROOT_DIR)/.terramate.lock 2>/dev/null)" ] ; then \
	bg_terramate "Lock file exists: $$(cat $(ROOT_DIR)/.terramate.lock 2>/dev/null)"; \
else \
	bg_terramate "Lock terramate for $$GOAL" ; \
	echo -n $(ENVIRONMENT_NAME) >$(ROOT_DIR)/.terramate.lock ; \
fi

TERRAMATE_UNLOCK = \
export SHELL="/bin/bash"; \
source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; \
if [ -f $(ROOT_DIR)/.terramate.lock ] ; then \
	echo "$$(cat $(ROOT_DIR)/.terramate.lock 2>/dev/null)" == "$(ENVIRONMENT_NAME)"; \
	if [ "$$(cat $(ROOT_DIR)/.terramate.lock 2>/dev/null)" == "$(ENVIRONMENT_NAME)" ] ; then \
		bg_terramate Unlock terramate; \
		rm $(ROOT_DIR)/.terramate.lock ; \
	else \
		bg_terramate "Lock file not ours: $$(cat $(ROOT_DIR)/.terramate.lock 2>/dev/null)"; \
	fi ; \
fi
