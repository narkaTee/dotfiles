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
    __n_latest_version="$(curl --retry 5 --retry-max-time 15 -sS https://api.github.com/repos/tj/n/releases/latest | jq -r .tag_name)"
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
        if [ -z "$__n_latest_version" ]; then
            # I have seent he curl command fail during sandbox image builds. I don't know why
            # So far it only happened once, but a ~30 Minute build that fails wastes time.
            # Addtionally to the retries I will hardcode a version to fall back to
            __n_latest_version="v10.2.0"
        fi
        (cd "$N_PREFIX/repo" || exit
        git checkout -f "$__n_latest_version")
        export PATH="$PATH:$HOME/.n-vm/repo/bin:$HOME/.n-vm/bin"
    fi
}

# init onepassword cli plugins if present
if [ -f "$HOME/.config/op/plugins.sh" ]; then
    . "$HOME/.config/op/plugins.sh"
fi

if [ -d "$HOME/.config/boxed" ] && hash bwrap 2>/dev/null; then
    export PATH="$PATH:$HOME/.config/boxed"
    alias npm="boxed npm -- npm"
    alias npx="boxed npm -- npx"
    alias pnpm="boxed npm -- pnpm"
    alias pnpx="boxed npm -- pnpx"
    alias yarn="boxed npm -- yarn"
    alias yarnpkg="boxed npm -- yarnpkg"
    alias aj="boxed ai-jail"
fi

# Setup EDITOR and VISUAL
if hash vim 2>/dev/null; then
    export EDITOR="vim"
    export VISUAL="$EDITOR"
else
    echo "Dude, no vim?!"
fi
