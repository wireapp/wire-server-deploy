ANSIBLE_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
CAILLEACH_DIR:=$(abspath ${ANSIBLE_DIR}/../../cailleach)
SHELL:=/usr/bin/env bash -eo pipefail

default: download

.PHONY: download
download: download-ansible-roles download-kubespray download-cli-binaries

.PHONY: download-kubespray
download-kubespray:
	poetry run ansible-playbook -i localhost, -c local download_kubespray.yml

.PHONY: download-cli-binaries
download-cli-binaries: download-ansible-roles
	# assumes /usr/local/bin is writable and on your PATH
	# assumes amd64 (change variables if needed)
	poetry run ansible-playbook -i localhost, -c local download_cli_binaries.yml

.PHONY: download-ansible-roles
download-ansible-roles:
	poetry run ansible-galaxy install -r requirements.yml

.PHONY: download-ansible-roles-force
download-ansible-roles-force:
	poetry run ansible-galaxy install -r requirements.yml --force

.PHONY: provision-sft
provision-sft: check-env
	poetry run ansible-playbook ${ANSIBLE_DIR}/provision-sft.yml  \
		-i ${ENV_DIR}/gen/terraform-inventory.yml \
		-i ${ENV_DIR}/inventory.yml \
		--private-key ${ENV_DIR}/operator-ssh.dec \
		-vv

.PHONY: bootstrap
bootstrap: check-env
	poetry run ansible-playbook ${ANSIBLE_DIR}/bootstrap.yml \
		-i ${ENV_DIR}/gen/terraform-inventory.yml \
		-i ${ENV_DIR}/inventory.yml \
		--private-key ${ENV_DIR}/operator-ssh.dec \
		-vv

.PHONY: check-env
check-env:
ifndef ENV_DIR
ifndef ENV
	$(error please define either ENV or ENV_DIR)
else
ENV_DIR=${CAILLEACH_DIR}/environments/${ENV}
endif
endif
ifeq ("$(wildcard ${ENV_DIR}/inventory.yml)", "")
	$(error please make sure ${ENV_DIR}/inventory.yml exists)
endif
ifeq ("$(wildcard ${ENV_DIR}/gen/terraform-inventory.yml)", "")
	$(error please make you have applied terraform for ${ENV_DIR})
endif
ifeq ("$(wildcard ${ENV_DIR}/operator-ssh.dec)", "")
	$(error please make sure ${ENV_DIR}/operator-ssh.dec exists and contains the private key to ssh into servers)
endif
