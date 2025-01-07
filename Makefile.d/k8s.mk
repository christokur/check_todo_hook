ROOT_DIR ?= $(PWD)/..

K8S_CLUSTER_NAME ?= $(ENVIRONMENT_NAME)
CLUSTER_NAMES := if [ ! -z "$$CLUSTER_NAME" ]; then \
	export CLUSTER_NAMES="$$CLUSTER_NAME"; \
else \
	export CLUSTER_NAMES=$$(aws eks --region $(AWS_REGION) list-clusters --output=text --profile=$(AWS_PROFILE) --query='@.clusters' | grep $(K8S_CLUSTER_NAME)); \
fi
UPDATE_KUBECONFIG := [ -z "$$CLUSTER_NAME" ] || aws eks --region $(AWS_REGION) update-kubeconfig --name $$CLUSTER_NAME --profile=$(AWS_PROFILE)
UPDATE_KUBECONFIG_ALL := [ -z "$$CLUSTER_NAMES" ] || for CLUSTER_NAME in $$CLUSTER_NAMES; do echo $$CLUSTER_NAME ; aws eks --region $(AWS_REGION) update-kubeconfig --name $$CLUSTER_NAME --profile=$(AWS_PROFILE) ; done
ARGOCD_LOGIN := [ -z "$${ARGOCD_HOSTNAME:-$(ARGOCD_HOSTNAME)}" ] || argocd login $${ARGOCD_HOSTNAME:-$(ARGOCD_HOSTNAME)} --sso --username $${ARGOCD_USERNAME:-$(ARGOCD_USERNAME)}

k8s_cluster_name:  # Print the k8s cluster name
	@set -o errexit ; \
	[ ! -z "$${K8S_CLUSTER_NAME:-$(K8S_CLUSTER_NAME)}" ] || export K8S_CLUSTER_NAME=$${ENVIRONMENT_NAME:-$(ENVIRONMENT_NAME)} ; \
	echo $${K8S_CLUSTER_NAME:-$(K8S_CLUSTER_NAME)}

k8s_context:  # Print the k8s cluster name
	@set -o errexit ; \
	[ ! -z "$${K8S_CLUSTER_NAME:-$(K8S_CLUSTER_NAME)}" ] || export K8S_CLUSTER_NAME=$${ENVIRONMENT_NAME:-$(ENVIRONMENT_NAME)} ; \
	K8S_CONTEXT=$$(kubectl config get-contexts | grep $${K8S_CLUSTER_NAME:-$(K8S_CLUSTER_NAME)} 2>/dev/null | awk '{ print $$2}') ; \
	kubectl config get-contexts $${K8S_CONTEXT} 2>&1

kubeconfig: # Update kubeconfig for the cluster
	@test ! -f environment.rc || . environment.rc ; \
	echo AWS_DEFAULT_REGION=$$AWS_DEFAULT_REGION ; \
	echo AWS_REGION=$$AWS_REGION ; \
	$(CLUSTER_NAMES) ; \
	echo CLUSTER_NAMES=$$CLUSTER_NAMES ; \
	for CLUSTER_NAME in $$CLUSTER_NAMES; do \
		$(UPDATE_KUBECONFIG) ; \
	done

firefly:  # Register firefly integration
	@export SHELL="/bin/bash"; \
	source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; \
	bg_firefly " $@ -- $$PWD " ; \
	[ ! -z "$${FIREFLY_ACCESS_KEY:-$(FIREFLY_ACCESS_KEY)}" ] || { echo 'Set FIREFLY_ACCESS_KEY' ; exit 1 ; } ; \
	[ ! -z "$${FIREFLY_SECRET_KEY:-$(FIREFLY_SECRET_KEY)}" ] || { echo 'Set FIREFLY_SECRET_KEY' ; exit 1 ; } ; \
	export FIREFLY_ACCESS_KEY=$${FIREFLY_ACCESS_KEY:-$(FIREFLY_ACCESS_KEY)} ; \
	export FIREFLY_SECRET_KEY=$${FIREFLY_SECRET_KEY:-$(FIREFLY_SECRET_KEY)} ; \
	helm repo add firefly https://gofireflyio.github.io/k8s-collector || true ; \
	helm repo update firefly ; \
	set -o errexit ; \
	[ ! -z "$${K8S_CLUSTER_NAME:-$(K8S_CLUSTER_NAME)}" ] || export K8S_CLUSTER_NAME=$${ENVIRONMENT_NAME:-$(ENVIRONMENT_NAME)} ; \
	K8S_CONTEXT=$$(kubectl config get-contexts | grep $${K8S_CLUSTER_NAME:-$(K8S_CLUSTER_NAME)} 2>/dev/null | awk '{ print $$2}') ; \
	[ -z "$${K8S_CONTEXT}" ] || { \
		kubectl config use-context $${K8S_CONTEXT} ; \
		helm install firefly firefly/firefly-k8s-collector --set accessKey=$${FIREFLY_ACCESS_KEY} --set secretKey=$${FIREFLY_SECRET_KEY} --set clusterId="$${K8S_CLUSTER_NAME:-$(K8S_CLUSTER_NAME)}" --set schedule="2\,17\,32\,47 * * * *"  --namespace=firefly --create-namespace || true ; \
	} ; \
