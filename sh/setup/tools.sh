# shellcheck shell=sh
# Load posix scripts
if [ -d "$HOME/.config/shrc.d/" ]; then
    for file in "$HOME"/.config/shrc.d/* ; do
        . "$file"
    done
    unset -v file
fi

# setup brew
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# source sdkman if it's installed
if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    . "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# Add RVM
if [ -d "$HOME/.rvm" ]; then
    export PATH="$PATH:$HOME/.rvm/bin"
fi

# Source rvm if it's installed
# $? will be 1 on a new shell if this is not in a extra if and rvm is not present.
if [ -f "$HOME/.rvm/scripts/rvm" ]; then
    . "$HOME/.rvm/scripts/rvm"
fi

if [ -d "$HOME/.cargo/bin" ]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# Add NVM
if [ -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"
    # use ifs to prevent non zero exit state if nvm is not installed
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        # To speed up the slow starup time
        # https://github.com/nvm-sh/nvm/issues/539#issuecomment-245791291
        # shellcheck disable=SC2240
        \. "$NVM_DIR/nvm.sh" --no-use  # This loads nvm
        # shellcheck disable=SC2142
        alias node='unalias node ; unalias npm ; nvm use default ; node $@'
        # shellcheck disable=SC2142
        alias npm='unalias node ; unalias npm ; nvm use default ; npm $@'
        alias nvmsrc='. "$NVM_DIR/nvm.sh"'
    fi
fi

if [ -d "$HOME/.asdf/" ]; then
    # we want asdf to also resolve "dynamic" versions like 20
    export ASDF_NODEJS_LEGACY_FILE_DYNAMIC_STRATEGY="latest_available"
    . "$HOME/.asdf/asdf.sh"
fi

if [ -d "$HOME/.n-vm/" ]; then
    export N_PREFIX="$HOME/.n-vm/"
    export PATH="$PATH:$HOME/.n-vm/repo/bin:$HOME/.n-vm/bin"
else
    n() {
        export N_PREFIX="$HOME/.n-vm"
        n_update
        unset -f n
    }
fi
n_update() {
    __n_latest_version="$(curl -sS https://api.github.com/repos/tj/n/releases/latest | jq -r .tag_name)"
    if [ ! -d "$N_PREFIX" ]; then
        echo "n is not installed, install? [y] or abort with ctrl+c"
    else
        echo "updating n to $__n_latest_version? [y] or abort with ctrl+c"
    fi
    # shellcheck disable=SC2034
    if read -r n_resp; then
        if [ ! -d "$N_PREFIX" ]; then
            mkdir -p "$N_PREFIX"
            git clone https://github.com/tj/n.git "$N_PREFIX/repo" || exit
        fi
        (cd "$N_PREFIX/repo" || exit
        git checkout -f "$__n_latest_version")
        export PATH="$PATH:$HOME/.n-vm/repo/bin:$HOME/.n-vm/bin"
    fi
}

# set PATH to include the global composer bin if it exists
if [ -d "$HOME/.composer/vendor/bin" ]; then
    PATH="$PATH:$HOME/.composer/vendor/bin"
fi

# set path to include pip bin if it exists
if [ -d "$HOME/.local/bin" ]; then
    PATH="$PATH:$HOME/.local/bin"
fi

# init onepassword cli plugins if present
if [ -f "$HOME/.config/op/plugins.sh" ]; then
    . "$HOME/.config/op/plugins.sh"
fi

# Setup EDITOR and VISUAL
if hash vim 2>/dev/null; then
    export EDITOR="vim"
    export VISUAL="$EDITOR"
else
    echo "Dude, no vim?!"
fi
