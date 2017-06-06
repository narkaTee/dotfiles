.PHONY: install \
	install-bash \
	install-git \
	install-tmux \
	clean

install: install-bash \
	install-git \
	install-tmux

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

install-git:
	install -d -m 0755 -- "$(HOME)/.gitconfig.d"
	install -pm 0644 -- git/gitconfig "$(HOME)/.gitconfig.d/.gitconfig"
	install -d -m 755 -- "$(HOME)/.git_template"
	cp -Trf git/git_template/ "$(HOME)/.git_template"
	git config --global --get-all include.path "$(HOME)/.gitconfig.d/.gitconfig" > /dev/null || \
	git config --global --add include.path "$(HOME)/.gitconfig.d/.gitconfig"

install-tmux: install-tmux-plugins
	install -pm 0644 -- tmux/tmux.conf "$(HOME)/.tmux.conf"

install-tmux-plugins:
	install -m 0755 -d -- "$(HOME)/.tmux/plugins/"
	cp -Trf tmux/plugins/ "$(HOME)/.tmux/plugins/"

clean:
	rm -rf build-*
