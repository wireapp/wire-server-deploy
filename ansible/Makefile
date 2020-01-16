.DEFAULT_GOAL := default


MKFILE_DIR = $(abspath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
CWD ?= $(CURDIR)


PYTHON_MODULES_DIR = $(MKFILE_DIR)/.python_modules
ANSIBLE_THIRDPARTY_ROLES = $(MKFILE_DIR)/roles-external


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


.PHONY: install
.SILENT: install
install: export PATH := $(PYTHON_MODULES_DIR)/bin:$(PATH)
install:
	pip install \
		--prefix $(PYTHON_MODULES_DIR) \
		--requirement $(MKFILE_DIR)/requirements.txt
	PYTHONPATH=$(PYTHON_MODULES_DIR)/lib/$$(basename $(PYTHON_MODULES_DIR)/lib/python*)/site-packages \
		ansible-galaxy install \
			--roles-path="$(ANSIBLE_THIRDPARTY_ROLES)" \
			--role-file="$(MKFILE_DIR)/requirements.yml"

.PHONY: play
.SILENT: play
play: export PATH := $(MKFILE_DIR)/bin:$(PYTHON_MODULES_DIR)/bin:$(PATH)
play: export PYTHONPATH = $(wildcard $(PYTHON_MODULES_DIR)/lib/python*)/site-packages
play: export ANSIBLE_CONFIG = $(MKFILE_DIR)/ansible.cfg
play: export ANSIBLE_ROLES_PATH = $(ANSIBLE_THIRDPARTY_ROLES):$(MKFILE_DIR)/roles
play:
	ansible-playbook \
		--inventory=localhost \
		--connection=local \
		--extra-vars="local_installation=True" \
		$(MKFILE_DIR)/download_cli_binaries.yml

.PHONY: clean
.SILENT: clean
clean:
	rm -rf \
		$(MKFILE_DIR)/bin \
		$(PYTHON_MODULES_DIR) \
		$(ANSIBLE_THIRDPARTY_ROLES)
