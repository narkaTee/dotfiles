# Load posix scripts
if [ -d "$HOME/.config/shrc.d/" ]; then
    for file in "$HOME"/.config/shrc.d/* ; do
        . "$file"
    done
    unset -v file
fi

# setup brew
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
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
if [[ -s "$HOME/.rvm/scripts/rvm" ]]; then
    source "$HOME/.rvm/scripts/rvm"
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
        \. "$NVM_DIR/nvm.sh" --no-use  # This loads nvm
        alias node='unalias node ; unalias npm ; nvm use default ; node $@'
        alias npm='unalias node ; unalias npm ; nvm use default ; npm $@'
    fi
fi

# set PATH to include the global composer bin if it exists
if [ -d "$HOME/.composer/vendor/bin" ]; then
    PATH="$PATH:$HOME/.composer/vendor/bin"
fi

# set path to include pip bin if it exists
if [ -d "$HOME/.local/bin" ]; then
    PATH="$PATH:$HOME/.local/bin"
fi

# Setup EDITOR and VISUAL
if hash vim 2>/dev/null; then
    export EDITOR="vim"
    export VISUAL="$EDITOR"
else
    echo "Dude, no vim?!"
fi
