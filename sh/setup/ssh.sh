# Predictable ssh auth sock
if [ ! -z "$SSH_AUTH_SOCK" ]; then
    permanent="$HOME/.ssh_auth_sock"
    if [ "$SSH_AUTH_SOCK" != "$permanent" ]; then
        ln -sf "$SSH_AUTH_SOCK" "$permanent"
        export SSH_AUTH_SOCK="$permanent"
    fi
fi

setup_ssh_pagent() {
    eval $(/usr/bin/ssh-pageant -q -r -a "/tmp/.ssh-pageant-$USERNAME")
}

setup_cli_agent() {
    ssh-add -l &>/dev/null
    if [ "$?" -eq "2" ]; then
        test -r ~/.ssh-agent && eval "$(<~/.ssh-agent)" >/dev/null

        ssh-add -l &>/dev/null
        if [ "$?" -eq "2" ]; then
            (umask 066; ssh-agent > ~/.ssh-agent)
            eval "$(<~/.ssh-agent)" >/dev/null
            ssh-add
        fi
    fi
}

# start auth agent
# I'm going to be a bit dirty here:
# Instead of checking for cygwin properly just checking for ssh-pageant
if hash ssh-pageant 2>/dev/null; then
    # start ssh-pageant (cygwin)
    setup_ssh_pagent
else
    # ssh-pagent not found use standard utils
    if ! hash gnome-keyring-daemon 2>/dev/null; then
        # gnome keyring not found use cli tooling
        setup_cli_agent
    fi
fi
