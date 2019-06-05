
default: download

.PHONY: download
download: download-ansible-roles download-kubespray

.PHONY: download-kubespray
download-kubespray:
	poetry run ansible-playbook -i localhost, -c local sync_kubespray.yml

.PHONY: download-ansible-roles
download-ansible-roles:
	poetry run ansible-galaxy install -r requirements.yml
