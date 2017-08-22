# try to determinate the git performance
_prompt_git_speed() {
    local git_start=$(date +%s%N)
    git rev-parse --is-inside-work-tree &> /dev/null
    local git_time=$((($(date +%s%N) - $git_start)/1000000))
    printf $git_time
}

# Checks whether this is a git repo
_is_git() {
    [ -n "$(git rev-parse --is-inside-work-tree 2>/dev/null)" ]
}

# Get the upstream status
_prompt_git_upstream_status() {
    _is_git || return

    status=""

    local diff="$(git rev-list --count --left-right @{u}...HEAD 2>/dev/null | sed 's/\t/,/g')"
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
    printf "$status"
}

# Get repo state
_prompt_git_state() {
    _is_git || return

    gitdir="$(git rev-parse --show-toplevel 2>/dev/null)/.git"

    status=""
    if [ -d "$gitdir/rebase-merge" -o -d "$gitdir/rebase-apply" ]; then
        status="rebase"
    elif [ -f "$gitdir/MERGE_HEAD" ]; then
        status="merge"
    elif [ -f "$gitdir/CHERRY_PICK_HEAD" ]; then
        status="cherry-pick"
    fi
    printf "$status"
}

# Get current branch
_prompt_git_branch() {
    _is_git || return
    local branch=$(
        git symbolic-ref -q HEAD 2>/dev/null ||
        git rev-parse --short HEAD 2>/dev/null
    )
    branch=${branch#refs/heads/}
    printf "$branch"
}

# Get reponame
_prompt_git_reponame() {
    _is_git || return
    local repopath=$(git rev-parse --show-toplevel 2>/dev/null)
    reponame=${repopath##*/}
    printf $reponame
}
