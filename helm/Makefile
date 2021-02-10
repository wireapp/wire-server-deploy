SHELL := /usr/bin/env bash -eo pipefail


# Overwriteable variables
#ENV_DIR

# Internal variables
ENVIRONMENTS_DIR := $(abspath $(CURDIR)/../../cailleach/environments)



ifndef ENV_DIR
ifndef ENV
$(error please define either ENV or ENV_DIR)
else
ENV_DIR = $(ENVIRONMENTS_DIR)/$(ENV)
endif
endif



################################### HELM ###################################

.PHONY: deploy
deploy: check-helm-inputs
	KUBECONFIG=$(ENV_DIR)/kubeconfig.dec \
	helmfile \
		--file $(ENV_DIR)/helmfile.yaml \
		sync \
			--concurrency 1



############################### CREDENTIALS ################################

.PHONY: decrypt
decrypt: kubeconfig.dec

.DELETE_ON_ERROR: $(ENV_DIR)/kubeconfig.dec
.PHONY: kubeconfig.dec
kubeconfig.dec: check-env-dir
	@if [ ! -e $(ENV_DIR)/$(basename $(@)) ]; then exit 0; fi
	sops -d $(ENV_DIR)/$(basename $(@)) > $(ENV_DIR)/$(@)
	@test -s $(ENV_DIR)/$(@) || (echo "[ERR] Failed decrypting kubeconfig" && exit 1)



################################ FAIL-SAFES ################################

.PHONY: check-env-dir
check-env-dir: $(ENV_DIR)
$(ENV_DIR):
	$(error directory: $(ENV_DIR) must exist)


.PHONY: check-helm-inputs
check-helm-inputs: $(ENV_DIR)/kubeconfig.dec

$(ENV_DIR)/kubeconfig.dec:
	$(error please make sure Kubernetes is installed and $(ENV_DIR)/kubeconfig.dec exists)
