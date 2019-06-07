
default: download

.PHONY: download
download: download-ansible-roles download-kubespray download-cli-binaries

.PHONY: download-kubespray
download-kubespray:
	poetry run ansible-playbook -i localhost, -c local download_kubespray.yml

.PHONY: download-cli-binaries
download-cli-binaries:
	# assumes /usr/local/bin is writable and on your PATH
	# assumes amd64 (change variables if needed)
	poetry run ansible-playbook -i localhost, -c local download_cli_binaries.yml

.PHONY: download-ansible-roles
download-ansible-roles:
	poetry run ansible-galaxy install -r requirements.yml
