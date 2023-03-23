## custom history behaviour
# all other history operations the global history by default if
# share_history is enabled.
# But I want the arrow keys to only use the local history. All other
# operations can still use the global history.

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=10000

setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt hist_save_no_dups
setopt hist_ignore_all_dups
# make shure to set shared history.
setopt share_history

# stolen from:
# https://superuser.com/questions/446594/separate-up-arrow-lookback-for-local-and-global-zsh-history
# arrow keys search local history
bindkey "${key[Up]}" up-line-or-local-history
bindkey "${key[Down]}" down-line-or-local-history
# macos + iterm2 + tmux
bindkey "^[[A" up-line-or-local-history
bindkey "^[[B" down-line-or-local-history
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

