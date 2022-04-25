SHELL := /usr/bin/env bash -eo pipefail
MKFILE_DIR := $(abspath $(dir $(abspath $(firstword $(MAKEFILE_LIST)))))

# NOTE: variables that can be defined/overwritten
#ENV_DIR or ENV

# NOTE: internal variables
# Please ignore the following line if you're not a Wire employee
ENVIRONMENTS_DIR := $(abspath $(CURDIR)/../cailleach/environments)



ifndef ENV_DIR
ifndef ENV
$(error "[ERR] Undefined variable: Please define either ENV or ENV_DIR")
else
ENV_DIR = $(ENVIRONMENTS_DIR)/$(ENV)
endif
endif



######################################## TERRAFORM #############################
export TF_DATA_DIR = $(ENV_DIR)/.terraform
TERRAFORM_WORKING_DIR = $(MKFILE_DIR)/terraform/environment

# Since the variable directory and the terraform working directory are not the
# same using a file custom.tf allows specifying additional terraform
# instructions not (yet) covered by the terraform/environment functionality.  A
# symlink is created before terraform init/apply/etc if such a file exists,
# otherwise it is removed (in case it was created during a previous Makefile
# invocation with a different ENV_DIR
.PHONY: custom-terraform
custom-terraform:
	if [ -f $(ENV_DIR)/custom.tf ]; then ln -sf $(ENV_DIR)/custom.tf $(TERRAFORM_WORKING_DIR)/custom.tf; else rm -f $(TERRAFORM_WORKING_DIR)/custom.tf; fi

# NOTE: leverage make's ability to noop if target already exists, but
#       this also means that re-init must be triggered explicitly
$(TF_DATA_DIR):
	cd $(TERRAFORM_WORKING_DIR) \
	&& terraform init -backend-config=$(ENV_DIR)/backend.tfvars

.PHONY: re-init
re-init: check-inputs-terraform custom-terraform
	make --always-make $(TF_DATA_DIR)

.PHONY: apply plan console destroy
apply plan console destroy: check-inputs-terraform custom-terraform $(TF_DATA_DIR)
	cd $(TERRAFORM_WORKING_DIR) \
	&& source $(ENV_DIR)/hcloud-token.dec \
	&& terraform $(@) -var-file=$(ENV_DIR)/terraform.tfvars

# FUTUREWORK: as of TF v0.14 second argument (MKFILE_DIR) is not supported anymore
.PHONY: force-unlock
force-unlock:
ifndef LOCK_ID
	$(error "[ERR] Undefined variable: LOCK_ID")
endif
	cd $(TERRAFORM_WORKING_DIR) \
	&& terraform force-unlock $(LOCK_ID) $(MKFILE_DIR)

.PHONY: output
output: check-inputs-terraform $(TF_DATA_DIR)
	cd $(TERRAFORM_WORKING_DIR) \
	&& terraform output -json

.PHONY: create-inventory
create-inventory: check-inputs-terraform $(TF_DATA_DIR)
	mkdir -p $(ENV_DIR)/gen
	cd $(TERRAFORM_WORKING_DIR) \
	&& terraform output -json inventory > $(ENV_DIR)/gen/terraform-inventory.yml


######################################## ANSIBLE ###############################
ANSIBLE_DIR = $(MKFILE_DIR)/ansible
export ANSIBLE_CONFIG = $(ANSIBLE_DIR)/ansible.cfg


.PHONY: bootstrap
bootstrap: check-inputs-ansible
	ansible-playbook $(ANSIBLE_DIR)/bootstrap.yml \
		-i $(ENV_DIR)/gen/terraform-inventory.yml \
		-i $(ENV_DIR)/inventory \
		--private-key $(ENV_DIR)/operator-ssh.dec \
		-vv

# Usage: ENV=bella make create-inventory renew-certs
# Then encrypt the new kubeconfig with sops
.PHONY: renew-certs
renew-certs: check-inputs-ansible
	ansible-playbook ${ANSIBLE_DIR}/kubernetes-renew-certs.yml \
		-i ${ENV_DIR}/gen/terraform-inventory.yml \
		-i ${ENV_DIR}/inventory \
		--private-key ${ENV_DIR}/operator-ssh.dec \
		-vv
	mv $(ANSIBLE_DIR)/kubeconfig.new ${ENV_DIR}/

# Usage: ENV=bella make create-inventory fetch-kubeconfig
# Then encrypt the new kubeconfig with sops
.PHONY: fetch-kubeconfig
fetch-kubeconfig: check-inputs-ansible
	ansible-playbook ${ANSIBLE_DIR}/kubernetes-fetch-kubeconfig.yml \
		-i ${ENV_DIR}/gen/terraform-inventory.yml \
		-i ${ENV_DIR}/inventory \
		--private-key ${ENV_DIR}/operator-ssh.dec \
		-vv
	mv $(ANSIBLE_DIR)/kubeconfig.new ${ENV_DIR}/

.PHONY: provision-sft
provision-sft: check-inputs-ansible
	ansible-playbook $(ANSIBLE_DIR)/provision-sft.yml \
		-i $(ENV_DIR)/gen/terraform-inventory.yml \
		-i $(ENV_DIR)/inventory \
		--private-key $(ENV_DIR)/operator-ssh.dec \
		-vv

# FUTUREWORK: https://github.com/zinfra/backend-issues/issues/1763
.PHONY: kube-minio-static-files
kube-minio-static-files: check-inputs-ansible check-inputs-helm
	ansible-playbook $(ANSIBLE_DIR)/kube-minio-static-files.yml \
		-i $(ENV_DIR)/gen/terraform-inventory.yml \
		-i $(ENV_DIR)/inventory \
		--private-key $(ENV_DIR)/operator-ssh.dec \
		--extra-vars "service_cluster_ip=$$(KUBECONFIG=$(ENV_DIR)/kubeconfig.dec kubectl get service fake-aws-s3 -o json | jq -r .spec.clusterIP)" \
		-vv

.PHONY: get-logs
get-logs: LOG_DIR ?= $(ENV_DIR)
get-logs: check-inputs-ansible
	ansible-playbook $(ANSIBLE_DIR)/get-logs.yml \
		-i $(ENV_DIR)/gen/terraform-inventory.yml \
		-i $(ENV_DIR)/inventory \
		--private-key $(ENV_DIR)/operator-ssh.dec \
		--extra-vars "log_host=$(LOG_HOST)" \
		--extra-vars "log_service=$(LOG_SERVICE)" \
		--extra-vars "log_since='$(LOG_SINCE)'" \
		--extra-vars "log_until='$(LOG_UNTIL)'" \
		--extra-vars "log_dir=$(LOG_DIR)"



######################################## HELM ##################################
.PHONY: deploy
deploy: check-inputs-helm
	KUBECONFIG=$(ENV_DIR)/kubeconfig.dec \
	helmfile \
		--file $(ENV_DIR)/helmfile.yaml \
		sync \
			--concurrency 1



######################################## CREDENTIALS ###########################

.PHONY: decrypt
decrypt: hcloud-token.dec operator-ssh.dec kubeconfig.dec

.PHONY: hcloud-token.dec
.SILENT: hcloud-token.dec
hcloud-token.dec: check-env-dir
	[ ! -e $(ENV_DIR)/$(basename $(@)) ] && exit 0 \
	|| ( \
		sops -d $(ENV_DIR)/$(basename $(@)) > $(ENV_DIR)/$(@) || rm $(ENV_DIR)/$(@); \
		test -s $(ENV_DIR)/$(@) || (echo "[ERR] Decryption failed: $(basename $(@))" && exit 1) \
	)

.PHONY: operator-ssh.dec
.SILENT: operator-ssh.dec
operator-ssh.dec: check-env-dir
	[ ! -e $(ENV_DIR)/$(basename $(@)) ] && exit 0 \
	|| ( \
		sops -d $(ENV_DIR)/$(basename $(@)) > $(ENV_DIR)/$(@) || rm $(ENV_DIR)/$(@); \
		test -s $(ENV_DIR)/$(@) || (echo "[ERR] Decryption failed: $(basename $(@))" && exit 1); \
		chmod 0600 $(ENV_DIR)/$(@) \
	)

.PHONY: kubeconfig.dec
.SILENT: kubeconfig.dec
kubeconfig.dec: check-env-dir
	[ ! -e $(ENV_DIR)/$(basename $(@)) ] && exit 0 \
	|| ( \
		sops -d $(ENV_DIR)/$(basename $(@)) > $(ENV_DIR)/$(@) || rm $(ENV_DIR)/$(@); \
		test -s $(ENV_DIR)/$(@) || (echo "[ERR] Decryption failed: $(basename $(@))" && exit 1) \
	)

.PHONY: clean-decrypt
clean-decrypt: check-env-dir
	rm $(ENV_DIR)/*.dec



######################################## Fail-safes ############################

.PHONY: check-env-dir
check-env-dir: $(ENV_DIR)
$(ENV_DIR):
	$(error "[ERR] Directory does not exist: $(@)")


.PHONY: check-inputs-terraform
check-inputs-terraform: $(ENV_DIR)/hcloud-token.dec

$(ENV_DIR)/hcloud-token.dec:
	$(error "[ERR] File does not exist: $(@)")


.PHONY: check-inputs-ansible
check-inputs-ansible: $(ENV_DIR)/inventory $(ENV_DIR)/gen/terraform-inventory.yml $(ENV_DIR)/operator-ssh.dec

$(ENV_DIR)/inventory:
	$(error "[ERR] Directory does not exist: $(@)")

$(ENV_DIR)/gen/terraform-inventory.yml:
	$(error "[ERR] File does not exist: $(@) - It's generated from Terraform output")

$(ENV_DIR)/operator-ssh.dec:
	$(error "[ERR] File does not exist: $(@) - It must contain the private key to ssh into servers")


.PHONY: check-inputs-helm
check-inputs-helm: $(ENV_DIR)/kubeconfig.dec

$(ENV_DIR)/kubeconfig.dec:
	$(error "[ERR] File does not exist: $(@) - Ensure that Kubernetes is installed")
