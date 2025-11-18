# shellcheck shell=sh
if [ -f "$HOME/.config/dircolors" ]; then
    eval "$(dircolors -b "$HOME/.config/dircolors")"
else
    eval "$(dircolors -b)"
fi

. "$HOME/.config/setup/helper_functions.sh"
