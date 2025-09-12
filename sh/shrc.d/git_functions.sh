# shellcheck shell=sh
# Checks whether this is a git repo
_is_git() {
    [ -n "$(git rev-parse --is-inside-work-tree 2>/dev/null)" ]
}
