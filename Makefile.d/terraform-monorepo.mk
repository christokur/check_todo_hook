ifeq ("$(IS_MONOREPO)","yes")
.PHONY: docs

docs: # Generate documentation
	@$(USE_MONOREPO)
	@for d in $(ROOT_DIR)/modules/*; do \
		if [ -z "$$(basename $$d | grep '(__pycache__)' 2>&1)" ] ; then \
			echo $$d; \
			cd $$d; \
			make -C $$d docs; \
			cd $(ROOT_DIR); \
		fi ; \
	done

fmt: # Format terraform code
	@$(USE_MONOREPO)
	@for d in $(ROOT_DIR)/modules/*; do \
		echo $$d; \
		cd $$d; \
		make -C $$d fmt; \
		cd $(ROOT_DIR); \
	done

#lock: # Terraform lock files
#	@$(USE_MONOREPO)
#	@for d in $(ROOT_DIR)/environment/*/*; do \
#		if [ -d $$d ] ; then \
#			echo $$d; \
#			cd $$d; \
#			make lock NEED_LOCK=no; \
#			cd $(ROOT_DIR); \
#		fi; \
#	done
endif
