.DEFAULT_GOAL := default
SHELL = /usr/bin/env bash -eo pipefail



MKFILE_DIR = $(abspath $(dir $(abspath $(firstword $(MAKEFILE_LIST)))))
CWD = $(CURDIR)
LOCAL_DIR = $(MKFILE_DIR)/.local

BIN_DIR = $(LOCAL_DIR)/bin
TEMP_DIR = $(LOCAL_DIR)/tmp

PYTHON_INTERPRETER	?= python3
VENV_DIR             = $(LOCAL_DIR)/.venv
VENV_BIN             = $(LOCAL_DIR)/.venv/bin
POETRY_LOCK          = $(MKFILE_DIR)/ansible/poetry.lock


PLATFORM := $(shell if echo $$OSTYPE | grep -q darwin; then echo darwin; else echo linux; fi)



SOPS_VERSION        ?= 3.2.0-r1
SOPS                 = $(BIN_DIR)/sops
SOPS_INCOMING        = $(TEMP_DIR)/sops-$(SOPS_VERSION).incoming
                       #NOTE: q3k's fork introduces `--config` option to subcommands; not merged into upstream yet
                       #TODO: keep an eye on https://github.com/mozilla/sops/pull/559
SOPS_URL             = https://github.com/q3k/sops/releases/download/$(SOPS_VERSION)/sops-$(SOPS_VERSION).$(PLATFORM)
SOPS_SHA256         ?= $(shell cat $(MKFILE_DIR)/versions/sops.256.sums | grep $(SOPS_VERSION).$(PLATFORM) | awk '{ print $$ 1 }')

TERRAFORM_VERSION       ?= 0.13.1
TERRAFORM_PATH           = $(BIN_DIR)/terraform
TERRAFORM                = $(TEMP_DIR)/terraform-$(TERRAFORM_VERSION)
TERRAFORM_INCOMING       = $(TEMP_DIR)/terraform-$(TERRAFORM_VERSION).incoming.zip
TERRAFORM_SIGS_INCOMING  = $(TEMP_DIR)/terraform-$(TERRAFORM_VERSION)-sigs.incoming
TERRAFORM_SUMS_INCOMING  = $(TEMP_DIR)/terraform-$(TERRAFORM_VERSION)-sums.incoming
TERRAFORM_URL_PREFIX     = https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)
TERRAFORM_FILE_PREFIX    = terraform_$(TERRAFORM_VERSION)
TERRAFORM_ZIP            = $(TERRAFORM_FILE_PREFIX)_$(PLATFORM)_amd64.zip
TERRAFORM_SUMS           = $(TERRAFORM_FILE_PREFIX)_SHA256SUMS
TERRAFORM_SUM            = $(TERRAFORM_FILE_PREFIX)_SHA256SUM
TERRAFORM_SIGS           = $(TERRAFORM_FILE_PREFIX)_SHA256SUMS.sig

GNUTAR_VERSION = 1.32
GNUTAR        = $(BIN_DIR)/tar
GNUTAR_INCOMING        = $(TEMP_DIR)/gnu-tar-$(GNUTAR_VERSION).incoming
GNUTAR_URL = https://homebrew.bintray.com/bottles/gnu-tar-$(GNUTAR_VERSION).catalina.bottle.1.tar.gz
GNUTAR_SHA256         ?= $(shell cat $(MKFILE_DIR)/versions/gnu-tar.256.sums | grep $(GNUTAR_VERSION) | awk '{ print $$ 1 }')



export PATH := $(VENV_BIN):$(BIN_DIR):$(PATH)


install: clean openssl sops jq terraform ansible gnu-tar



$(LOCAL_DIR)/%/:
	mkdir -p $(@)


.PHONY: terraform
terraform: export GNUPGHOME = $(LOCAL_DIR)/.gnupg
terraform: $(TERRAFORM)
$(TERRAFORM): $(BIN_DIR)/ $(TEMP_DIR)/ $(TERRAFORM_INCOMING) $(TERRAFORM_SUMS_INCOMING) $(TERRAFORM_SIGS_INCOMING)
	unzip "$(TERRAFORM_INCOMING)" -d $(TEMP_DIR)
	mv $(TEMP_DIR)/terraform "$(TERRAFORM)"
	gpg --import "$(MKFILE_DIR)/versions/hashicorp.pgp"
	gpg --verify "$(TERRAFORM_SIGS_INCOMING)" "$(TERRAFORM_SUMS_INCOMING)"
	# Verify the SHASUM matches the binary.
	@ [ $$(openssl dgst -sha256 "$(TERRAFORM_INCOMING)" | awk '{ print $$ 2 }') \
		== $$(cat "$(TERRAFORM_SUMS_INCOMING)" | grep "$(TERRAFORM_ZIP)" | awk '{ print $$ 1 }') ] \
		|| ( echo "Invalid SHA256." && rm "$(TERRAFORM)" && exit 1 )
	cp $(TERRAFORM) $(TERRAFORM_PATH)

$(TERRAFORM_INCOMING): $(TEMP_DIR)/
	curl -sL "$(TERRAFORM_URL_PREFIX)/$(TERRAFORM_ZIP)" > "$(TERRAFORM_INCOMING)"

$(TERRAFORM_SUMS_INCOMING): $(TEMP_DIR)/
	curl -sL "$(TERRAFORM_URL_PREFIX)/$(TERRAFORM_SUMS)" > "$(TERRAFORM_SUMS_INCOMING)"

$(TERRAFORM_SIGS_INCOMING): $(TEMP_DIR)/
	curl -sL "$(TERRAFORM_URL_PREFIX)/$(TERRAFORM_SIGS)" > "$(TERRAFORM_SIGS_INCOMING)"


.PHONY: sops
sops: $(SOPS)
$(SOPS): $(BIN_DIR)/ $(SOPS_INCOMING)
	@ [ $$(openssl dgst -sha256 "$(SOPS_INCOMING)" | awk '{ print $$ 2 }') == $(SOPS_SHA256) ] || ( echo "Invalid SHA256." && rm $(SOPS_INCOMING) && exit 1 )
	cp -f "$(SOPS_INCOMING)" "$@"
	chmod +x "$@"

$(SOPS_INCOMING): $(TEMP_DIR)/
	curl -sL $(SOPS_URL) > "$@"


.PHONY: gnu-tar
gnu-tar: $(GNUTAR)
$(GNUTAR): $(BIN_DIR)/ $(GNUTAR_INCOMING)
	@ [ $$(openssl dgst -sha256 "$(GNUTAR_INCOMING)" | awk '{ print $$ 2 }') == $(GNUTAR_SHA256) ] || ( echo "Invalid SHA256." && rm $(GNUTAR_INCOMING) && exit 1 )
	rm -rf $(TEMP_DIR)/gnu-tar
	mkdir -p $(TEMP_DIR)/gnu-tar
	tar \
		--extract \
		--verbose \
		--strip-components 2 \
		--directory "$(TEMP_DIR)/gnu-tar" \
		--file "$(GNUTAR_INCOMING)"
	mv $(TEMP_DIR)/gnu-tar/bin/gtar "$@"
	chmod 755 "$@"

$(GNUTAR_INCOMING): $(TEMP_DIR)/
	curl -sL $(GNUTAR_URL) > "$@"


$(VENV_DIR):
	rm -rf "$@"
	$(PYTHON_INTERPRETER) -m venv "$@"
	$(VENV_BIN)/pip install poetry
	# Ubuntu bug, see https://stackoverflow.com/questions/7446187/no-module-named-pkg-resources
	$(VENV_BIN)/pip install setuptools

.PHONY: ansible
ansible: export POETRY_CACHE_DIR = $(LOCAL_DIR)/.poetry/cache
ansible: export POETRY_VIRTUALENVS_CREATE = false
ansible: $(VENV_DIR) $(POETRY_LOCK)
	cd $(dir $(POETRY_LOCK)) && poetry install

# Run 'poetry update' (use this make target after making changes to pyproject.yaml,
# or if there have been new version of python dependencies releases)
.PHONY: poetry-update
poetry-update: export POETRY_CACHE_DIR = $(LOCAL_DIR)/.poetry/cache
poetry-update: export POETRY_VIRTUALENVS_CREATE = false
poetry-update: $(VENV_DIR) $(POETRY_LOCK)
	cd $(dir $(POETRY_LOCK)) && poetry update


.PHONY: clean
clean:
	rm -rf "${LOCAL_DIR}"


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
	@which $(*) >/dev/null 2>&1 || (echo "$* is not installed - please use your system package manager (eg. apt, brew) to install it."; exit 1)



ENV_DIRECTORIES = $(MKFILE_DIR)/../cailleach/environments


init-%: export ENV_DIR = $(ENV_DIRECTORIES)/$(*)
init-%:
	cd $(MKFILE_DIR)/terraform/environment \
	&& make init


apply-%: export ENV_DIR = $(ENV_DIRECTORIES)/$(*)
apply-%:
	sops -d $(ENV_DIR)/hcloud-token > $(ENV_DIR)/hcloud-token.dec
	make -C $(MKFILE_DIR)/terraform/environment \
		apply \
		create-inventory

bootstrap-%: export OBJC_DISABLE_INITIALIZE_FORK_SAFETY = YES
bootstrap-%: export POETRY_VIRTUALENVS_CREATE = false
bootstrap-%: export ENV_DIR = $(ENV_DIRECTORIES)/$(*)
bootstrap-%:
	sops -d $(ENV_DIR)/operator-ssh > $(ENV_DIR)/operator-ssh.dec
	chmod 600 $(ENV_DIR)/operator-ssh.dec
	make -C $(MKFILE_DIR)/ansible \
		download-ansible-roles-force \
		download-kubespray \
		provision-sft
