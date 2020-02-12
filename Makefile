.PHONY: install \
	test-sh \
	install-sh \
	test-bash \
	install-bash \
	install-git \
	install-tmux \
	install-tmux-plugins \
	install-mintty \
	install-ideavim \
	install-zsh-dotfiles \
	clean

install: install-bash \
	install-git \
	install-tmux \
	install-mintty \
	install-ideavim \
	install-zsh-dotfiles

install-sh: test-sh
	rm -rf "$(HOME)/.config/shrc.d"
	install -m 0755 -d -- "$(HOME)/.config/shrc.d"
	install -pm 0644 -- sh/shrc.d/* "$(HOME)/.config/shrc.d"

test-sh:
	@for file in sh/shrc.d/*.sh; do \
		if [ -f "$$file" ] && ! dash -n "$$file"; then \
			exit 1; \
		fi \
	done
	@echo "POSIX-Scripts successfully parsed"

install-bash: test-bash \
	install-sh
	rm -rf "$(HOME)/.bashrc.d"
	install -m 0755 -d -- "$(HOME)/.bashrc.d"
	install -pm 0644 -- bash/bashrc "$(HOME)/.bashrc"
	install -pm 0644 -- bash/bashrc.d/* "$(HOME)/.bashrc.d"
	install -pm 0644 -- bash/bash_profile "$(HOME)/.bash_profile"

test-bash:
	@for file in bash/* bash/bashrc.d/*.bash; do \
		if [ -f "$$file" ] && ! bash -n "$$file"; then \
			exit 1; \
		fi \
	done
	@echo "BASH-Scripts successfully parsed"

install-git:
	rm -rf "$(HOME)/.config/git-scripts"
	install -m 0755 -d -- "$(HOME)/.config/git-scripts"
	cp -Trf git/git-scripts/ "$(HOME)/.config/git-scripts"
	rm -rf "$(HOME)/.gitconfig.d"
	install -d -m 0755 -- "$(HOME)/.gitconfig.d"
	install -pm 0644 -- git/gitconfig "$(HOME)/.gitconfig.d/.gitconfig"
	rm -rf "$(HOME)/.git_template"
	install -d -m 755 -- "$(HOME)/.git_template"
	cp -Trf git/git_template/ "$(HOME)/.git_template"
	git config --global --get-all include.path "$(HOME)/.gitconfig.d/.gitconfig" > /dev/null || \
	git config --global --add include.path "$(HOME)/.gitconfig.d/.gitconfig"

install-tmux: install-tmux-plugins
	install -pm 0644 -- tmux/tmux.conf "$(HOME)/.tmux.conf"

install-tmux-plugins:
	rm -rf "$(HOME)/.tmux/plugins/"
	install -m 0755 -d -- "$(HOME)/.tmux/plugins/"
	cp -Trf tmux/plugins/ "$(HOME)/.tmux/plugins/"

install-mintty:
	if hash cygcheck.exe 2> /dev/null; then \
		cp -f "mintty/minttyrc" "$(HOME)/.minttyrc"; \
	fi

install-ideavim:
	install -pm 0644 -- .ideavimrc "$(HOME)/.ideavimrc"

install-zsh-dotfiles:
	install -pm 0644 -- zsh/zshrc "$(HOME)/.zshrc"
	install -pm 0644 -- zsh/p10k.zsh "$(HOME)/.p10k.zsh"
