## custom history behaviour
# all other history operations the global history by default if
# share_history is enabled.
# But I want the arrow keys to only use the local history. All other
# operations can still use the global history.

# make shure to set shared history.
# OMZ sets this automatically, who knows how long I'm gonne use it.
setopt share_history

# stolen from:
# https://superuser.com/questions/446594/separate-up-arrow-lookback-for-local-and-global-zsh-history
# arrow keys search local history
bindkey "${key[Up]}" up-line-or-local-history
bindkey "${key[Down]}" down-line-or-local-history
# CTRL + arrow key searches global history
bindkey "^[[1;5A" up-line-or-history    # [CTRL] + Cursor up
bindkey "^[[1;5B" down-line-or-history  # [CTRL] + Cursor down
# rev history search
bindkey '^R' history-incremental-search-backward

up-line-or-local-history() {
    zle set-local-history 1
    zle up-line-or-history
    zle set-local-history 0
}
zle -N up-line-or-local-history
down-line-or-local-history() {
    zle set-local-history 1
    zle down-line-or-history
    zle set-local-history 0
}
zle -N down-line-or-local-history

