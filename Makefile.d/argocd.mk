ROOT_DIR ?= $(PWD)/..
TERRAFORM_TEMPLATE ?= cookiecutter/cloud-services-applications
SHELL := /bin/bash
NAMESPACE ?= "argocd"
CHART_VERSION ?= '5.5.4'

update: # Update helm chart repos
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update

upgrade: update # Deploy helm chart
	set -x ; \
	source environment.rc ; \
	export CTX=$$(kubectl config get-contexts --output=name | grep $$AWS_DEFAULT_REGION | grep $${ACCOUNT_ID} | grep $${CLUSTER_NAME}) ; \
	helm --kube-context "$${CTX}" upgrade -i --version $(CHART_VERSION) -n $(NAMESPACE) -f ./argocd-values.yaml argocd-$$ENVIRONMENT_NAME argo/argo-cd


register: kubeconfig # Add the cluster to the ArgoCD instance
	@set -o errexit ; \
	. $(ROOT_DIR)/cicd/rc/argocd_register_cluster.rc ; \
	export ARGOCD_HOSTNAME=$${ARGOCD_HOSTNAME:-$(ARGOCD_HOSTNAME)} ; \
	export ARGOCD_USERNAME=$${ARGOCD_USERNAME:-$(ARGOCD_USERNAME)} ; \
	export AWS_REGION=$$(echo $(AWS_REGION)) ; \
	export AWS_PROFILE=$$(echo $(AWS_PROFILE)) ; \
	$(CLUSTER_NAMES) ; \
	argocd_register_cluster $(ENVIRONMENT_NAME) ; \



unregister: kubeconfig # Add the cluster to the ArgoCD instance
	@set -o errexit ; \
	. $(ROOT_DIR)/cicd/rc/argocd_register_cluster.rc ; \
	export ARGOCD_HOSTNAME=$${ARGOCD_HOSTNAME:-$(ARGOCD_HOSTNAME)} ; \
	export ARGOCD_USERNAME=$${ARGOCD_USERNAME:-$(ARGOCD_USERNAME)} ; \
	export AWS_REGION=$$(echo $(AWS_REGION)) ; \
	export AWS_PROFILE=$$(echo $(AWS_PROFILE)) ; \
	$(CLUSTER_NAMES) ; \
	argocd_unregister_cluster $(ENVIRONMENT_NAME) ; \


reregister: unregister register # Re-register the cluster with ArgoCD
