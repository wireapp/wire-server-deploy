ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
# Please ignore this if you're not a wire employee
CAILLEACH_DIR:=$(abspath ${ROOT_DIR}/../../../cailleach)
SHELL:=/usr/bin/env bash

export TF_DATA_DIR=${ENV_DIR}/.terraform

.PHONY: init
init: check-env
	terraform init -backend-config=${ENV_DIR}/backend.tfvars

.PHONY: output
output: check-env
	terraform output -json

.PHONY: force-unlock
force-unlock: check-env
ifndef LOCK_ID
	$(error please define LOCK_ID)
endif
	terraform force-unlock ${LOCK_ID} ${ROOT_DIR}

.PHONY: create-inventory
create-inventory: check-env
	mkdir -p ${ENV_DIR}/gen && \
		terraform output -json inventory > ${ENV_DIR}/gen/terraform-inventory.yml

.PHONY: apply plan console destroy
apply plan console destroy:
	source ${ENV_DIR}/hcloud-token.dec && \
		terraform $@ -var-file=${ENV_DIR}/terraform.tfvars

.PHONY: check-env
check-env:
ifndef ENV_DIR
ifndef ENV
	$(error please define either ENV or ENV_DIR)
else
ENV_DIR=${CAILLEACH_DIR}/environments/${ENV}
endif
endif
