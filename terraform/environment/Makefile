ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
# Please ignore this if you're not a wire employee
CAILLEACH_DIR:=$(abspath ${ROOT_DIR}/../../../cailleach)
SHELL:=/usr/bin/env bash

.PHONY: init
init: check-env
	cd ${ENV_DIR} && \
		terraform init -backend-config=${ENV_DIR}/backend.tfvars ${ROOT_DIR}

.PHONY: apply
apply: check-env
	cd ${ENV_DIR} && \
		source hcloud-token.dec && \
		terraform apply -var 'inventory_file=./gen/terraform-inventory.yml' ${ROOT_DIR}

.PHONY: plan
plan: check-env
	cd ${ENV_DIR} && \
		source hcloud-token.dec && \
		terraform plan -var 'inventory_file=./gen/terraform-inventory.yml' ${ROOT_DIR}

.PHONY: destroy
destroy: check-env
	cd ${ENV_DIR} && \
		source hcloud-token.dec && \
		terraform destroy -var 'inventory_file=./gen/terraform-inventory.yml' ${ROOT_DIR}

.PHONY: console
console: check-env
	cd ${ENV_DIR} && \
		source hcloud-token.dec && \
		terraform console -var 'inventory_file=./gen/terraform-inventory.yml' ${ROOT_DIR}

.PHONY: force-unlock
force-unlock: check-env
ifndef LOCK_ID
	$(error please define LOCK_ID)
endif
	cd ${ENV_DIR} && \
		terraform force-unlock ${LOCK_ID} ${ROOT_DIR}

.PHONY: check-env
check-env:
ifndef ENV_DIR
ifndef ENV
	$(error please define either ENV or ENV_DIR)
else
ENV_DIR=${CAILLEACH_DIR}/environments/${ENV}
endif
endif
