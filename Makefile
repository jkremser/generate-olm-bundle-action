# Copyright 2021 The k8gb Contributors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Generated by GoLic, for more details see: https://github.com/AbsaOSS/golic
###############################
#       DOTENV
###############################
ifneq ($(wildcard ./.env),)
	include .env
	export
endif


###############################
#		CONSTANTS
###############################
BUNDLE_VERSION ?= 0.0.4
BUNDLE_IMAGE_NAME ?= k8gb-bundle
BUNDLE_IMAGE_REPO ?= docker.io/jkremser#todo: change (must be public)
OPERATOR_SDK_VERSION ?= v1.12.0
OPERATOR_SDK_DL_URL=https://github.com/operator-framework/operator-sdk/releases/download/$(OPERATOR_SDK_VERSION)
PREFERRED_NS=k8gbtest
PWD ?=  $(shell pwd)

ifndef NO_COLOR
YELLOW=\033[0;33m
CYAN=\033[1;36m
# no color
NC=\033[0m
endif

ifeq ($(shell uname -m),x86_64)
	ARCH ?= amd64
else 
	ifeq ($(shell uname -m),aarch64)
		ARCH ?= arm64
	else
		ARCH ?= $(shell uname -m)
	endif
endif

OS=$(shell uname | tr '[:upper:]' '[:lower:]')

 
###############################
#		TARGETS
###############################

.PHONY: deployment-blueprint
deployment-blueprint: ## Renders the helm chart to provide a snapshot of the deployment manifests
	@echo "$(CYAN)Generating deployment yaml manifests using helm..$(NC)\n"
	-rm -Rf ./deploy-tmp
	mkdir deploy-tmp
	cd chart/k8gb && helm dependency update
	helm -n placeholder template ./chart/k8gb \
		--name-template=k8gb \
		--set k8gb.securityContext.runAsUser=null \
		--set k8gb.log.format=simple \
		--set k8gb.log.level=info > ./deploy-tmp/deploy-all.yaml
	@echo "$(YELLOW)Deployment manifests have been generated$(NC)\n"

.PHONY: bundle-generate
bundle-generate: ## Generate bundle directory for Operator Lifecycle Manager
	@echo "$(CYAN)Generating bundle..$(NC)\n"
	$(call operator-sdk,generate,bundle,--crds-dir,chart/k8gb/templates/crds,--deploy-dir,./deploy-tmp/deploy-all.yaml,-v,$(BUNDLE_VERSION))
	-rm -Rf ./deploy-tmp

needs-yq:
	@which yq > /dev/null || ( echo Tool yq not found, please install it first, see http://mikefarah.github.io/yq/#install && exit 1 )

.PHONY: bundle-add-examples
bundle-add-examples: needs-yq ## Adds the content of two example custom resources to the CSV manifest
	@echo "$(CYAN)Adding examples to CSV file..$(NC)\n"
	-@echo [ > json.tmp
	-@yq eval -o=j -I 0 deploy/crds/k8gb.absa.oss_v1beta1_gslb_cr_failover.yaml | sed "s|\"|\\\\\"|g" >> json.tmp
	-@echo , >> json.tmp
	-@yq eval -o=j -I 0 deploy/crds/k8gb.absa.oss_v1beta1_gslb_cr.yaml | sed "s|\"|\\\\\"|g" >> json.tmp
	-@echo ] >> json.tmp
	yq eval '.metadata.annotations.alm-examples = "'"$$(cat json.tmp | tr -d '\n')"'"' \
	     --inplace bundle/manifests/k8gb.clusterserviceversion.yaml
	-@rm json.tmp
	@echo "$(YELLOW)Examples with CRs have been added to CSV manifest$(NC)\n"

.PHONY: bundle-add-crd-info
bundle-add-crd-info: needs-yq ## Enrich the .spec.customresourcedefinitions.owned w/ displayName and description
	@echo "$(CYAN)Adding additional information to CSV manifest..$(NC)\n"
	yq eval '.spec.customresourcedefinitions.owned[] |= select(.kind).displayName = .kind' \
	   --inplace  bundle/manifests/k8gb.clusterserviceversion.yaml
	yq eval '.spec.customresourcedefinitions.owned[] |= select(.kind == "Gslb").description = "Gslb is the Schema for the gslbs API"' \
	   --inplace  bundle/manifests/k8gb.clusterserviceversion.yaml
	yq eval '.spec.customresourcedefinitions.owned[] |= select(.kind == "DNSEndpoint").description = "Endpoint is a high-level way of a connection between a service and an IP"' \
	   --inplace  bundle/manifests/k8gb.clusterserviceversion.yaml
	@echo "$(YELLOW)Display names and descriptions have been added$(NC)\n"

.PHONY: bundle-fix-dockerfile
bundle-fix-dockerfile: ## Removes 1 line from bundle dockerfile (scorecard entry)
	sed -i "/^COPY bundle\/tests\/scorecard/d" bundle.Dockerfile
	@echo "$(YELLOW)Scorecard entry has been removed from the bundle.Dockerfile$(NC)\n"

.PHONY: bundle-remove-local
bundle-remove-local: ## Removes ./bundle and ./bundle.Dockerfile (these are generated by make bundle-generate)
	-rm -Rf ./bundle
	-rm -Rf ./bundle.Dockerfile
	@echo "$(YELLOW)Local ./bundle directory has been removed$(NC)\n"

.PHONY: bundle-full
bundle-full: deployment-blueprint bundle-remove-local bundle-generate bundle-fix-dockerfile bundle-add-examples bundle-add-crd-info bundle-validate ## Prepares the container image w/ the bundle including the necessary intermediate steps
	@echo "\n\n$(YELLOW)Full container image ($(BUNDLE_IMAGE_REPO)/$(BUNDLE_IMAGE_NAME):$(BUNDLE_VERSION)) w/ bundle has been built$(NC)\n"
	@echo "Continue with make bundle-image-push\n"

.PHONY: bundle-validate
bundle-validate: ## Validate the CSV file
	@echo "$(CYAN)Validating bundle..$(NC)\n"
	$(call operator-sdk,bundle,validate,./bundle,--optional-values=index-path=bundle.Dockerfile)
	@echo "$(YELLOW)Bundle is OK!$(NC)\n"

.PHONY: bundle-image-build
bundle-image-build: ## Builds the container image w/ bundle metadata
	@echo "$(CYAN)Building bundle container image..$(NC)\n"
	docker build -f bundle.Dockerfile -t $(BUNDLE_IMAGE_REPO)/$(BUNDLE_IMAGE_NAME):$(BUNDLE_VERSION) .

.PHONY: bundle-image-push
bundle-image-push: ## Push the bundle image to the pre-defined image registry
	docker push $(BUNDLE_IMAGE_REPO)/$(BUNDLE_IMAGE_NAME):$(BUNDLE_VERSION)
	@echo "\nTo deploy the new bundle do: make bundle-deploy\n"

# this assumes the OpenShift is up and running
.PHONY: bundle-deploy
bundle-deploy: ## Deploys the bundle image into OpenShift's catalog, this will also deploy the operator
	$(call operator-sdk,run,bundle,-n,$(PREFERRED_NS),$(BUNDLE_IMAGE_REPO)/$(BUNDLE_IMAGE_NAME):$(BUNDLE_VERSION))

.PHONY: cleanup
cleanup: ## Deletes the k8gb operator from the OpenShift catalog
	$(call operator-sdk,cleanup,k8gb)

.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'


###############################
#		FUNCTIONS
###############################

define operator-sdk
	@which operator-sdk > /dev/null || { \
		echo "$(YELLOW)Downloading operator-sdk..$(NC)" ; \
		curl -sLo /usr/bin//operator-sdk $(OPERATOR_SDK_DL_URL)/operator-sdk_$(OS)_$(ARCH) ; \
		chmod +x /usr/bin//operator-sdk ; \
	}
	operator-sdk $1 $2 $3 $4 $5 $6 $7 $8 $9 $(10)
endef