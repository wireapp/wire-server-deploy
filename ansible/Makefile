ANSIBLE_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
# Please ignore this if you're not a wire employee
CAILLEACH_DIR:=$(abspath ${ANSIBLE_DIR}/../../cailleach)
SHELL:=/usr/bin/env bash -eo pipefail

.PHONY: provision-sft
provision-sft: check-env
	ansible-playbook ${ANSIBLE_DIR}/provision-sft.yml  \
		-i ${ENV_DIR}/gen/terraform-inventory.yml \
		-i ${ENV_DIR}/inventory \
		--private-key ${ENV_DIR}/operator-ssh.dec \
		-vv

.PHONY: bootstrap
bootstrap: check-env
	ansible-playbook ${ANSIBLE_DIR}/bootstrap.yml \
		-i ${ENV_DIR}/gen/terraform-inventory.yml \
		-i ${ENV_DIR}/inventory \
		--private-key ${ENV_DIR}/operator-ssh.dec \
		-vv

# FUTUREWORK: https://github.com/zinfra/backend-issues/issues/1763
.PHONY: kube-minio-static-files
kube-minio-static-files: check-env
	ansible-playbook ${ANSIBLE_DIR}/kube-minio-static-files.yml \
		-i ${ENV_DIR}/gen/terraform-inventory.yml \
		-i ${ENV_DIR}/inventory \
		--private-key ${ENV_DIR}/operator-ssh.dec \
		--extra-vars "service_cluster_ip=$$(KUBECONFIG=${ENV_DIR}/gen/artifacts/admin.conf kubectl get service fake-aws-s3 -o json | jq -r .spec.clusterIP)" \
		-vv

LOG_UNTIL ?= "now"
.PHONY: get-logs
get-logs: check-env
ifndef LOG_HOST
	$(error please define LOG_HOST)
endif
ifndef LOG_SERVICE
	$(error please define LOG_SERVICE)
endif
ifndef LOG_SINCE
	$(error please define LOG_SINCE)
endif
	ansible-playbook ${ANSIBLE_DIR}/get-logs.yml \
		-i ${ENV_DIR}/gen/terraform-inventory.yml \
		-i ${ENV_DIR}/inventory.yml \
		--private-key ${ENV_DIR}/operator-ssh.dec \
		--extra-vars "log_host=${LOG_HOST}" \
		--extra-vars "log_service=${LOG_SERVICE}" \
		--extra-vars "log_since='${LOG_SINCE}'" \
		--extra-vars "log_until='${LOG_UNTIL}'" \
		--extra-vars "log_dir=${LOG_DIR}"

.PHONY: ensure-env-dir
ensure-env-dir:
ifndef ENV_DIR
ifndef ENV
	$(error please define either ENV or ENV_DIR)
else
ENV_DIR=${CAILLEACH_DIR}/environments/${ENV}
endif
endif

${ENV_DIR}/inventory:
	$(error please make sure ${ENV_DIR}/inventory exists)

${ENV_DIR}/gen/terraform-inventory.yml:
	$(error please make you have applied terraform for ${ENV_DIR})

${ENV_DIR}/operator-ssh.dec:
	$(error please make sure ${ENV_DIR}/operator-ssh.dec exists and contains the private key to ssh into servers)

.PHONY: check-env
check-env: ensure-env-dir ${ENV_DIR}/operator-ssh.dec ${ENV_DIR}/gen/terraform-inventory.yml ${ENV_DIR}/inventory
