PLATFORM = $(shell if [[ $$OSTYPE =~ darwin* ]]; then echo darwin; else echo linux; fi)

.PHONY: galaxy
galaxy:
	ansible-galaxy install -r roles-external/requirements.yml
