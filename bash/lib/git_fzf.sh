#!/usr/bin/env bash

__git_fzf_script="${BASH_SOURCE[0]}"

__git_fzf_list_branches() {
    git branch "$@" --color=always --sort=-committerdate --sort=-HEAD --format=$'%(HEAD) %(color:yellow)%(refname:short) %(color:green)(%(committerdate:relative))\t%(color:blue)%(subject)%(color:reset)' | column -ts$'\t'
}

__git_fzf_list_changes() {
    git status --short --untracked-files=all
}

__git_fzf_list_commits() {
    git log --format="%C(auto)%h%d %s %C(green)%cr" --color=always
}

case "${1:-}" in
    branches)
        shift
        __git_fzf_list_branches "$@"
        ;;
esac

# shellcheck disable=SC2120
__git_fzf_branches() {
    __git_fzf_list_branches | fzf \
        -q "$*" \
        --nth 1..2 \
        --border \
        --border-label "Branches" \
        --header "CTRL+b (all branches) CTRL+n (branches)" \
        --ansi \
        --tiebreak index \
        --color hl:underline,hl+:underline \
        --bind "ctrl-b:change-border-label(All Branches)+reload(\"$__git_fzf_script\" branches -a)" \
        --bind "ctrl-n:change-border-label(Branches)+reload(\"$__git_fzf_script\" branches)" \
        --preview-window down,border-top,40% \
        --preview "git graph --color=always \$(cut -c3- <<< {} | cut -d' ' -f1) --" \
        | sed 's/^\* //' | sed 's/^  origin\///' | awk '{print $1}'
}

__git_fzf_branch_switch() {
    git_fzf_target_branch="$(__git_fzf_branches)"
    [ -n "$git_fzf_target_branch" ] && git switch "$git_fzf_target_branch"
}

__git_fzf_commits() {
    __git_fzf_list_commits | fzf \
        -q "$*" \
        --nth 2.. \
        --accept-nth 1 \
        --border \
        --border-label "Commits" \
        --ansi \
        --tiebreak index \
        --preview='git show --color=always --pretty="format:Author: %cn <%ce>%nDate: %cd%n---%n%s%n%n%b" --compact-summary -p {1}' \
        | tr -d '\n' | copy
}

__git_fzf_add() {
    local files
    files="$(__git_fzf_list_changes | fzf \
        --multi \
        --nth 2 \
        --accept-nth 2 \
        --border \
        --border-label "Commits" \
        --ansi \
        --tiebreak index \
        --preview='git diff --color=always -- {2}')"
    if [ -n "$files" ]; then
        local git_fzf_selected=()
        while IFS= read -r line; do
            git_fzf_selected+=("$line")
        done <<<"$files"
        git add "$@" "${git_fzf_selected[@]}"
    fi
}
