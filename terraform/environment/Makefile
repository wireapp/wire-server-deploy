SHELL := /usr/bin/env bash
ROOT_DIR := ${shell dirname ${realpath ${firstword ${MAKEFILE_LIST}}}}
TOK = hcloud-token
SSH = operator-ssh

# Please ignore the following line if you're not a wire employee
CAILLEACH_DIR:=${abspath ${ROOT_DIR}/../../../cailleach}

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
	${error please define LOCK_ID}
endif
	terraform force-unlock ${LOCK_ID} ${ROOT_DIR}

.PHONY: create-inventory
create-inventory: check-env
	mkdir -p ${ENV_DIR}/gen && \
		terraform output -json inventory > ${ENV_DIR}/gen/terraform-inventory.yml

.PHONY: view-inventory
view-inventory: check-env
	@mkdir -p ${ENV_DIR}/gen && \
		terraform output -json inventory

.PHONY: apply plan console refresh
apply plan console refresh:
	source ${ENV_DIR}/hcloud-token.dec && \
		terraform $@ -var-file=${ENV_DIR}/terraform.tfvars

.PHONY: state-list
state-list:
	source ${ENV_DIR}/hcloud-token.dec && \
		terraform state list 

.PHONY: destroy
destroy:
	rm -rf ${ENV_DIR}/gen && \
		source ${ENV_DIR}/hcloud-token.dec && \
			terraform $@ -var-file=${ENV_DIR}/terraform.tfvars

.PHONY: check-env
check-env:
ifndef ENV_DIR
ifndef ENV
	${error please define either ENV or ENV_DIR}
else
ENV_DIR=${CAILLEACH_DIR}/environments/${ENV}
endif
endif

.PHONY: decrypt
decrypt: ${ENV_DIR}/${TOK}.dec ${ENV_DIR}/${SSH}.dec

${ENV_DIR}/${TOK}.dec: check-env
	echo ${ENV_DIR}/${TOK}.dec
	sops -d ${ENV_DIR}/${TOK} > ${ENV_DIR}/${TOK}.dec

${ENV_DIR}/${SSH}.dec: check-env
	sops -d ${ENV_DIR}/${SSH} > ${ENV_DIR}/${SSH}.dec
	chmod 0600 ${ENV_DIR}/${SSH}.dec

.PHONY: clean
clean: check-env
	rm ${ENV_DIR}/*.dec
