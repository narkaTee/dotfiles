# shellcheck shell=bash disable=SC2155 # there are a lot of direct asignments in here but with correct error handling
# try to determinate the git performance
_prompt_git_speed() {
    local git_start=$(date +%s)
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
    local git_end=$(date +%s)
    local git_time=$((git_end - git_start))
    printf "%s" "$git_time"
}

# Get the upstream status
_prompt_git_upstream_status() {
    _is_git || return

    status=""

    local diff="$(git rev-list --count --left-right '@{u}...HEAD' 2>/dev/null | sed 's/\t/,/g')"
    case "$diff" in
        "") # no upstream or HEAD detached
            ;;
        "0,0") # no divergence
            status="u="
            ;;
        "0,"*) # ahead of upstream
            status="u+${diff#0,}"
            ;;
        *",0") # behind of upstream
            status="u-${diff%,0}"
            ;;
        *) # both
            status="u+${diff#*,}-${diff%,*}"
            ;;
    esac
    printf "%s" "$status"
}

# Get repo state
_prompt_git_state() {
    _is_git || return

    gitdir="$(git rev-parse --show-toplevel 2>/dev/null)/.git"

    status=""
    if [ -d "$gitdir/rebase-merge" ] || [ -d "$gitdir/rebase-apply" ]; then
        status="rebase"
    elif [ -f "$gitdir/MERGE_HEAD" ]; then
        status="merge"
    elif [ -f "$gitdir/CHERRY_PICK_HEAD" ]; then
        status="cherry-pick"
    fi
    printf "%s" "$status"
}

# Get current branch
_prompt_git_branch() {
    _is_git || return
    local branch=$(
        git symbolic-ref -q HEAD 2>/dev/null ||
        git rev-parse --short HEAD 2>/dev/null
    )
    branch=${branch#refs/heads/}
    printf "%s" "$branch"
}

# Get reponame
_prompt_git_reponame() {
    _is_git || return
    local repopath=$(git rev-parse --show-toplevel 2>/dev/null)
    reponame=${repopath##*/}
    printf "%s" "$reponame"
}
