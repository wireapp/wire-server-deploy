ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
CAILLEACH_DIR:=$(abspath ${ROOT_DIR}/../../../cailleach)
ENV_DIR:=${CAILLEACH_DIR}/environments/${ENV}
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

.PHONY: check-env
check-env:
ifndef ENV
	$(error ENV is not set)
endif
