## load modules
zmodload -i zsh/complist

## adjust FPATH
# brew autocompletion
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
fi

## initialize comp system
autoload -Uz compinit
compinit -d "$HOME/.cache/.zcompdump-${ZSH_VERSION}"

## adjust comp settings
unsetopt menu_complete
setopt auto_menu
setopt complete_in_word
setopt always_to_end

eval "$(dircolors -b)"
zstyle ':completion:*' menu select
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'

zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "$HOME/.cache"

bindkey -M emacs "${terminfo[kcbt]}" reverse-menu-complete
bindkey -M viins "${terminfo[kcbt]}" reverse-menu-complete
bindkey -M vicmd "${terminfo[kcbt]}" reverse-menu-complete

autoload -U +X bashcompinit && bashcompinit