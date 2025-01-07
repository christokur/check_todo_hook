
# The following targets are for supporting terraform state migration for ECR repos
# ex:
# make ENV_DIR_SRC=environment/infdev/cloud-services-dev ENV_DIR_DST=environment/infdev/cs--dev--1--tools--use2 ecr_state_migrate_prepare
ecr_state_migrate_prepare: state_migrate_validate # ECR migration: Pull remote state and move all from src to dst in local state files
	@export STATE_SRC="$(ROOT_DIR)/$$(basename $(ENV_DIR_SRC))-ecr.tfstate"; \
	export STATE_DST="$(ROOT_DIR)/$$(basename $(ENV_DIR_DST))-ecr.tfstate"; \
	export STATE_OUT="$$STATE_SRC"; cd $(ENV_DIR_SRC); make state_pull ecr_state_pull; cd $(ROOT_DIR); \
	export STATE_OUT="$$STATE_DST"; cd $(ENV_DIR_DST); make state_pull ecr_state_pull; cd $(ROOT_DIR); \
	cd $(ENV_DIR_DST); make ecr_state_migrate; cd $(ROOT_DIR); \
	echo "ECR state migrated in local files. Now run make ecr_state_migrate_apply to push changes to the remote backends."

ecr_state_migrate_apply: state_migrate_validate # ECR migration: Push modified local state to remote state
	@export STATE_SRC="$(ROOT_DIR)/$$(basename $(ENV_DIR_SRC))-ecr.tfstate"; \
	export STATE_DST="$(ROOT_DIR)/$$(basename $(ENV_DIR_DST))-ecr.tfstate"; \
	export STATE_IN="$$STATE_SRC"; cd $(ENV_DIR_SRC); make ecr_state_push; cd $(ROOT_DIR); \
	export STATE_IN="$$STATE_DST"; cd $(ENV_DIR_DST); make ecr_state_push; cd $(ROOT_DIR); \
	echo "ECR state pushed to remote backends. Now update the ECR configuration for the source and destination environments."

# make ENV_DIR_SRC=environment/infdev/cloud-services-dev ENV_DIR_DST=environment/infdev/cs--dev--1--tools--use2 ecr_state_migrate_apply_full
ecr_state_migrate_apply_full: ecr_state_migrate_apply # ECR migration: Full automation: Push state, modify configs and check plan
	export STATE_IN="$$STATE_SRC"; cd $(ENV_DIR_SRC); make ecr_config_disable generate plan; cd $(ROOT_DIR); \
	export STATE_IN="$$STATE_DST"; cd $(ENV_DIR_DST); make ecr_config_enable generate plan; cd $(ROOT_DIR); \
	cd $(ENV_DIR_SRC); make summarize; cd $(ROOT_DIR); \
	cd $(ENV_DIR_DST); make summarize; cd $(ROOT_DIR); \
	echo "There should be no changes in the plan summaries."

# The following targets are for supporting terraform state migration for route53 hosted zones
# ex:
# make ENV_DIR_SRC=environment/infdev/cloud-services-dev ENV_DIR_DST=environment/infdev/cs--dev--1--tools--use2 route53_state_migrate_prepare
route53_state_migrate_prepare: state_migrate_validate # route53 migration: Pull remote state and move route53 resource in local state files
	@export STATE_SRC="$(ROOT_DIR)/$$(basename $(ENV_DIR_SRC))-services.tfstate"; \
	export STATE_DST="$(ROOT_DIR)/$$(basename $(ENV_DIR_DST))-services.tfstate"; \
	export STATE_OUT="$$STATE_SRC"; cd $(ENV_DIR_SRC); make services_state_pull; cd $(ROOT_DIR); \
	export STATE_OUT="$$STATE_DST"; cd $(ENV_DIR_DST); make services_state_pull; cd $(ROOT_DIR); \
	cd $(ENV_DIR_DST); make route53_state_migrate; cd $(ROOT_DIR); \
	echo "Route53 state migrated in local files. Now run make route53_state_migrate_apply to push changes to the remote backends."

route53_state_migrate_apply: state_migrate_validate # route53 migration: Push modified local state to remote state
	@export STATE_SRC="$(ROOT_DIR)/$$(basename $(ENV_DIR_SRC))-services.tfstate"; \
	export STATE_DST="$(ROOT_DIR)/$$(basename $(ENV_DIR_DST))-services.tfstate"; \
	export STATE_IN="$$STATE_SRC"; cd $(ENV_DIR_SRC); make services_state_push; cd $(ROOT_DIR); \
	export STATE_IN="$$STATE_DST"; cd $(ENV_DIR_DST); make services_state_push; cd $(ROOT_DIR); \
	echo "services state pushed to remote backends. Now update the services configuration for the source and destination environments."

# make ENV_DIR_SRC=environment/infdev/cloud-services-dev ENV_DIR_DST=environment/infdev/cs--dev--1--tools--use2 route53_state_migrate_apply_full
route53_state_migrate_apply_full: route53_state_migrate_apply # route53 migration: Full (no tf apply) automation: Push state, modify configs, check plan
	export STATE_IN="$$STATE_SRC"; cd $(ENV_DIR_SRC); make route53_config_disable generate plan; cd $(ROOT_DIR); \
	export STATE_IN="$$STATE_DST"; cd $(ENV_DIR_DST); make route53_config_enable generate plan; cd $(ROOT_DIR); \
	cd $(ENV_DIR_SRC); echo "SRC:"; make show | grep 'module.cloud_services.module.cs_app.module.route53'; cd $(ROOT_DIR); \
	cd $(ENV_DIR_DST); echo "DST:"; make show | grep 'module.cloud_services.module.cs_app.module.route53'; cd $(ROOT_DIR); \
	echo "There will be changes in the plan summaries but the route53 hosted zone should only have tags/environment name modified in the destination."
	echo "Now verify the changes are correct and run 'make apply' in each environment"
