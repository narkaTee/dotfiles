# set PATH to include git-scripts if it exists
if [ -d "$HOME/.config/git/scripts" ]; then
    PATH="$PATH:$HOME/.config/git/scripts"
fi

# Should be the last path modification so it takes precedence
# set PATH to include the private bin if it exists
if [ -d "$HOME/bin" ]; then
    PATH="$HOME/bin:$PATH"
fi

if [ -f "$HOME/.config/env.local.sh" ]; then
  . "$HOME/.config/env.local.sh"
fi
