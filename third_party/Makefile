# This Makefile allows for installing of third party tools for 'classic' Linux distributions,
# by downloading them from the Internet and dropping them into third_party/bin.
# This should mostly be called via bin/wire_server_deploy-tools.

# We use some bashisms here. Generally, systems without bash are unsupported.
SHELL = bash

ifndef wire_server_deploy_root
$(error wire_server_deploy_root is not set - did you source env.sh?)
endif
ifndef wire_server_deploy_local
$(error wire_server_deploy_local is not set - did you source env.sh?)
endif

PLATFORM            := $(shell if echo $$OSTYPE | grep -q darwin; then echo darwin; else echo linux; fi)
THIRD_PARTY          = $(wire_server_deploy_root)/third_party
BIN_DIR              = $(THIRD_PARTY)/bin

# We use venv to create a pure Python virtual environment, independant of
# system packages.
# We then install poetry into it for dependency management.
PYTHONINTERP        ?= python3
VENV_DIR             = $(THIRD_PARTY)/venv
VENV_BIN             = $(THIRD_PARTY)/venv/bin
POETRY_LOCK          = $(THIRD_PARTY)/poetry.lock

HELM_VERSION        ?= v3.1.1
HELM                 = $(BIN_DIR)/helm
HELM_INCOMING        = $(BIN_DIR)/helm-$(HELM_VERSION).incoming.tar.gz
HELM_URL             = https://get.helm.sh/helm-$(HELM_VERSION)-$(PLATFORM)-amd64.tar.gz
HELM_SHA256         ?= $(shell cat $(wire_server_deploy_root)/third_party/versions/helm.256.sums | grep $(HELM_VERSION)-$(PLATFORM) | awk '{ print $$ 1 }')

## DEPRECATED: Remove as soon as all environments are based on helm 3.
HELM2_VERSION        ?= v2.13.1
HELM2                 = $(BIN_DIR)/helm2
HELM2_INCOMING        = $(BIN_DIR)/helm-$(HELM2_VERSION).incoming.tar.gz
HELM2_URL             = https://get.helm.sh/helm-$(HELM2_VERSION)-$(PLATFORM)-amd64.tar.gz
HELM2_SHA256         ?= $(shell cat $(wire_server_deploy_root)/third_party/versions/helm.256.sums | grep $(HELM2_VERSION)-$(PLATFORM) | awk '{ print $$ 1 }')

SOPS_VERSION        ?= 3.2.0-r1
SOPS                 = $(BIN_DIR)/sops
SOPS_INCOMING        = $(BIN_DIR)/sops-$(SOPS_VERSION).incoming
                       #NOTE: q3k's fork introduces `--config` option to subcommands; not merged into upstream yet
                       #TODO: keep an eye on https://github.com/mozilla/sops/pull/559
SOPS_URL             = https://github.com/q3k/sops/releases/download/$(SOPS_VERSION)/sops-$(SOPS_VERSION).$(PLATFORM)
SOPS_SHA256         ?= $(shell cat $(wire_server_deploy_root)/third_party/versions/sops.256.sums | grep $(SOPS_VERSION).$(PLATFORM) | awk '{ print $$ 1 }')

KUBECTL_VERSION     ?= v1.12.1
KUBECTL              = $(BIN_DIR)/kubectl
KUBECTL_INCOMING     = $(BIN_DIR)/kubectl-$(KUBECTL_VERSION).incoming
KUBECTL_URL          = https://storage.googleapis.com/kubernetes-release/release/$(KUBECTL_VERSION)/bin/$(PLATFORM)/amd64/kubectl
KUBECTL_SHA512      ?= $(shell cat $(wire_server_deploy_root)/third_party/versions/kubectl.512.sums | grep $(KUBECTL_VERSION)-$(PLATFORM) | awk '{ print $$ 1 }')

JSONNET_VERSION     ?= v0.14.0
JSONNET              = $(BIN_DIR)/jsonnet
JSONNET_INCOMING     = $(BIN_DIR)/jsonnet-$(JSONNET_VERSION).incoming
JSONNET_URL          = https://github.com/google/jsonnet/releases/download/$(JSONNET_VERSION)/jsonnet-bin-$(JSONNET_VERSION)-$(PLATFORM).tar.gz
JSONNET_SHA256      ?= $(shell cat $(wire_server_deploy_root)/third_party/versions/jsonnet.256.sums | grep $(JSONNET_VERSION)-$(PLATFORM) | awk '{ print $$ 1 }')

TERRAFORM_VERSION       ?= 0.12.18
TERRAFORM_SYM            = $(BIN_DIR)/terraform
TERRAFORM                = $(BIN_DIR)/terraform-$(TERRAFORM_VERSION)
TERRAFORM_INCOMING       = $(BIN_DIR)/terraform-$(TERRAFORM_VERSION).incoming.zip
TERRAFORM_SIGS_INCOMING  = $(BIN_DIR)/terraform-$(TERRAFORM_VERSION)-sigs.incoming
TERRAFORM_SUMS_INCOMING  = $(BIN_DIR)/terraform-$(TERRAFORM_VERSION)-sums.incoming
TERRAFORM_URL_PREFIX     = https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)
TERRAFORM_FILE_PREFIX    = terraform_$(TERRAFORM_VERSION)
TERRAFORM_ZIP            = $(TERRAFORM_FILE_PREFIX)_$(PLATFORM)_amd64.zip
TERRAFORM_SUMS           = $(TERRAFORM_FILE_PREFIX)_SHA256SUMS
TERRAFORM_SUM            = $(TERRAFORM_FILE_PREFIX)_SHA256SUM
TERRAFORM_SIGS           = $(TERRAFORM_FILE_PREFIX)_SHA256SUMS.sig

TMATE_VERSION           ?= 2.4.0
TMATE_PLATFORM           = linux
TMATE_URL                = https://github.com/tmate-io/tmate/releases/download/$(TMATE_VERSION)/tmate-$(TMATE_VERSION)-static-$(TMATE_PLATFORM)-amd64.tar.xz
TMATE                    = $(BIN_DIR)/tmate
TMATE_INCOMING           = $(BIN_DIR)/tmate-$(TMATE_VERSION).incoming
TMATE_SHA256             = $(shell cat $(wire_server_deploy_root)/third_party/versions/tmate.256.sums | grep $(TMATE_VERSION)-static-$(TMATE_PLATFORM)-amd64 | awk '{ print $$ 1 }')

default: all

all: $(BIN_DIR) openssl helm kubectl sops jsonnet jq terraform tmate ansible

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

.PHONY: tmate
ifeq ($(PLATFORM),darwin)
tmate: system.tmate
else
tmate: $(TMATE)
$(TMATE): $(BIN_DIR) $(TMATE_INCOMING)
	@ [ $$(openssl dgst -sha256 "$(TMATE_INCOMING)" | awk '{ print $$ 2 }') == $(TMATE_SHA256) ] || ( echo "Invalid SHA256." && exit 1)
	tar -xvf $(TMATE_INCOMING) -C $(BIN_DIR)
	mv $(BIN_DIR)/tmate-$(TMATE_VERSION)-static-$(TMATE_PLATFORM)-amd64/tmate $(TMATE)
endif

$(TMATE_INCOMING):
	curl -sL "$(TMATE_URL)" > "$(TMATE_INCOMING)"

.PHONY: terraform
terraform: export GNUPGHOME = $(THIRD_PARTY)/.gnupg
terraform: $(TERRAFORM)
$(TERRAFORM): $(BIN_DIR) $(TERRAFORM_INCOMING) $(TERRAFORM_SUMS_INCOMING) $(TERRAFORM_SIGS_INCOMING)
	unzip "$(TERRAFORM_INCOMING)" -d /tmp
	mv /tmp/terraform "$(TERRAFORM)"
	gpg --import "$(wire_server_deploy_root)/third_party/keys/hashicorp.pgp"
	# Verify the signature file is untampered.
	gpg --verify "$(TERRAFORM_SIGS_INCOMING)" "$(TERRAFORM_SUMS_INCOMING)"
	# Verify the SHASUM matches the binary.
	@ [ $$(openssl dgst -sha256 "$(TERRAFORM_INCOMING)" | awk '{ print $$ 2 }') \
		== $$(cat "$(TERRAFORM_SUMS_INCOMING)" | grep "$(TERRAFORM_ZIP)" | awk '{ print $$ 1 }') ] \
		|| ( echo "Invalid SHA256." && rm "$(TERRAFORM)" && exit 1 )
	ln -fs "$(TERRAFORM)" "$(TERRAFORM_SYM)"

$(TERRAFORM_INCOMING):
	curl -sL "$(TERRAFORM_URL_PREFIX)/$(TERRAFORM_ZIP)" > "$(TERRAFORM_INCOMING)"

$(TERRAFORM_SUMS_INCOMING):
	curl -sL "$(TERRAFORM_URL_PREFIX)/$(TERRAFORM_SUMS)" > "$(TERRAFORM_SUMS_INCOMING)"

$(TERRAFORM_SIGS_INCOMING):
	curl -sL "$(TERRAFORM_URL_PREFIX)/$(TERRAFORM_SIGS)" > "$(TERRAFORM_SIGS_INCOMING)"


.PHONY: kubectl
kubectl: $(KUBECTL)
$(KUBECTL): $(BIN_DIR) $(KUBECTL_INCOMING)
	@ [ $$(openssl dgst -sha512 "$(KUBECTL_INCOMING)" | awk '{ print $$ 2 }') == $(KUBECTL_SHA512) ] || ( echo "Invalid SHA512." && rm $(KUBECTL_INCOMING) && exit 1 )
	cp -f "$(KUBECTL_INCOMING)" "$@"
	chmod +x "$@"

$(KUBECTL_INCOMING):
	curl -sL $(KUBECTL_URL) > $(KUBECTL_INCOMING)

.PHONY: helm
helm: export HELM_HOME ?= $(wire_server_deploy_root)/.local/helm
helm: $(HELM)
$(HELM): $(BIN_DIR) $(HELM_INCOMING)
	@ [ $$(openssl dgst -sha256 "$(HELM_INCOMING)" | awk '{ print $$ 2 }') == $(HELM_SHA256) ] || ( echo "Invalid SHA256." && rm $(HELM_INCOMING) && exit 1 )
	mkdir -p "$(BIN_DIR)/helm-incoming"
	tar -xvf "$(HELM_INCOMING)" -C "$(BIN_DIR)/helm-incoming"
	mv "$(BIN_DIR)/helm-incoming/$(PLATFORM)-amd64/helm" "$(BIN_DIR)/"
	touch "$(HELM)"
	rm -r "$(BIN_DIR)/helm-incoming"
	mkdir -p $(HELM_HOME)
	helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com
	helm repo add cos https://centerforopenscience.github.io/helm-charts/

$(HELM_INCOMING):
	curl -sL $(HELM_URL) > $(HELM_INCOMING)

## DEPRECATED: Remove as soon as all environments are based on helm 3.
.PHONY: helm2
helm2: export HELM_HOME ?= $(wire_server_deploy_root)/.local/helm
helm2: $(HELM2)
$(HELM2): $(BIN_DIR) $(HELM2_INCOMING)
	@ [ $$(openssl dgst -sha256 "$(HELM_INCOMING)" | awk '{ print $$ 2 }') == $(HELM_SHA256) ] || ( echo "Invalid SHA256." && rm $(HELM_INCOMING) && exit 1 )
	mkdir -p "$(BIN_DIR)/helm-incoming"
	tar -xvf "$(HELM2_INCOMING)" -C "$(BIN_DIR)/helm-incoming"
	mv "$(BIN_DIR)/helm-incoming/$(PLATFORM)-amd64/tiller" "$(BIN_DIR)/"
	mv "$(BIN_DIR)/helm-incoming/$(PLATFORM)-amd64/helm" "$(BIN_DIR)/helm2"
	touch "$(HELM2)"
	rm -r "$(BIN_DIR)/helm-incoming"
	mkdir -p $(HELM_HOME)
	helm2 init -c
	helm2 repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com
	helm2 repo add cos https://centerforopenscience.github.io/helm-charts/
	helm2 repo remove local || true

## DEPRECATED: Remove as soon as all environments are based on helm 3.
$(HELM2_INCOMING):
	curl -sL $(HELM2_URL) > $(HELM2_INCOMING)

.PHONY: sops
sops: $(SOPS)
$(SOPS): $(BIN_DIR) $(SOPS_INCOMING)
	@ [ $$(openssl dgst -sha256 "$(SOPS_INCOMING)" | awk '{ print $$ 2 }') == $(SOPS_SHA256) ] || ( echo "Invalid SHA256." && rm $(SOPS_INCOMING) && exit 1 )
	cp -f "$(SOPS_INCOMING)" "$@"
	chmod +x "$@"

$(SOPS_INCOMING):
	curl -sL $(SOPS_URL) > "$@"

.PHONY: jsonnet
jsonnet: $(JSONNET)
# NOTE: re-build on darwin currently broken https://github.com/google/jsonnet/issues/710
ifeq ($(PLATFORM),darwin)
$(JSONNET): system.jsonnet
else
$(JSONNET): $(BIN_DIR) $(JSONNET_INCOMING)
	@ [ $$(openssl dgst -sha256 "$(JSONNET_INCOMING)" | awk '{ print $$ 2 }') == $(JSONNET_SHA256) ] || ( echo "Invalid SHA256." && rm $(JSONNET_INCOMING) && exit 1 )
	(cd $(BIN_DIR) && tar -xvf "$(JSONNET_INCOMING)" jsonnet )
endif

$(JSONNET_INCOMING):
	curl -sL $(JSONNET_URL) > "$@"

# Packages that are common and stable enough that we don't download them
# ourselves, and instead ask the user to use their favourite package manager
# to do that for them.

.PHONY: jq
jq: system.jq

.PHONY: openssl
openssl: system.openssl

system.%:
	@ # Which is very chatty, and will print out the entire $PATH if a binary is
	@ # not found. Silence it by piping outputs to /dev/null.
	@which $* >/dev/null 2>&1 || (echo "$* is not installed - please use your system package manager (eg. apt, brew) to install it."; exit 1)

# Install venv with poetry.
# This is not the target venv into which actual dependencies are installed,
# but an intermediary one into which we install poetry. Poetry then takes care
# of dependency resolution, but creates its own venv outside of wire_server_deploy.
# #
# third_party/poetry-install will then install wrappers to allow running poetry
# installed packages without having to use 'poetry run' or 'poetry shell'.
.PHONY: venv.install
venv.install: $(VENV_DIR)
$(VENV_DIR): $(REQUIREMENTS_LOCK)
	rm -rf "$@"
	$(PYTHONINTERP) -m venv "$@"
	$(VENV_BIN)/pip install poetry
	# Ubuntu bug, see https://stackoverflow.com/questions/7446187/no-module-named-pkg-resources
	$(VENV_BIN)/pip install setuptools

# Install python-based dependencies with poetry, and set up wrappers in
# third_party/bin.
.PHONY: ansible python-jsonnet
ansible python-jsonnet: $(VENV_DIR) $(POETRY_LOCK)
	( cd $(THIRD_PARTY) && $(VENV_BIN)/poetry install )
	$(THIRD_PARTY)/poetry-install.sh


# Run 'poetry update' (use this make target after making changes to pyproject.yaml,
# or if there have been new version of python dependencies releases)
.PHONY: poetry-update
poetry-update: $(VENV_DIR)
	( cd $(THIRD_PARTY) && $(VENV_BIN)/poetry update )
	$(THIRD_PARTY)/poetry-install.sh

# Cleanup rules.

.PHONY: clean mrproper
mrproper: clean
clean:
	rm -rf "${VENV_DIR}"
	rm -rf "${BIN_DIR}"
	rm -rf "$(THIRD_PARTY)/.gnupg"
