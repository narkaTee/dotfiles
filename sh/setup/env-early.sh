if [ -f "$HOME/.config/dircolors" ]; then
    eval "$(dircolors -b "$HOME/.config/dircolors")"
else
    eval "$(dircolors -b)"
fi
