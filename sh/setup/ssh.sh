# shellcheck shell=sh
setup_ssh_pagent() {
    eval "$(/usr/bin/ssh-pageant -q -r -a "/tmp/.ssh-pageant-$USERNAME")"
}

setup_cli_agent() {
    ssh-add -l > /dev/null 2>&1
    # return code 2 means aent could not be contacted
    if [ "$?" -eq "2" ]; then
        test -r ~/.ssh-agent && . ~/.ssh-agent >/dev/null

        ssh-add -l > /dev/null 2>&1
        if [ "$?" -eq "2" ]; then
            (umask 066; ssh-agent > ~/.ssh-agent)
            . ~/.ssh-agent >/dev/null
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
    # ssh-pagent not found use other utils
    if [ -e "$HOME/.1password/agent.sock" ]; then
        # 1pw socket found use that
        export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
    elif ! hash gnome-keyring-daemon 2>/dev/null; then
        # gnome keyring not found use cli tooling
        setup_cli_agent
    fi
fi

# Predictable ssh auth sock, this enables the ssh agent forwarding to work when connecting to
# an tmux session from an previous ssh session.
# This needs to be at the end of the script to re-link the detected socket
if [ -n "$SSH_AUTH_SOCK" ]; then
    permanent="$HOME/.ssh_auth_sock"
    if [ "$SSH_AUTH_SOCK" != "$permanent" ]; then
        ln -sf "$SSH_AUTH_SOCK" "$permanent"
        export SSH_AUTH_SOCK="$permanent"
    fi
fi
