.PHONY: install \
	install-bash

install: install-bash

install-bash: test-bash
	install -m 0755 -d -- \
		"$(HOME)/.bashrc.d"
	install -pm 0644 -- bash/bashrc "$(HOME)/.bashrc"
	install -pm 0644 -- bash/bashrc.d/* "$(HOME)/.bashrc.d"
	install -pm 0644 -- bash/bash_profile "$(HOME)/.bash_profile"

test-bash:
	@for file in bash/* bash/bashrc.d/*; do \
		if [ -f "$$file" ] && ! bash -n "$$file"; then \
			exit 1; \
		fi \
	done
	@echo "Scripts successfully parsed"

