
default: download

.PHONY: download
download: download-ansible-roles download-kubespray


.PHONY: download-kubespray
download-kubespray:


.PHONY: download-ansible-roles
download-ansible-roles:
	poetry run ansible-galaxy install -r requirements.yml
