if hash fzf 2> /dev/null; then
    __git_fzf_zsh_branches() {
        LBUFFER+="$(__git_fzf_branches)"
    }

    zle -N __git_fzf_zsh_branches
    bindkey "^B" __git_fzf_zsh_branches
fi
