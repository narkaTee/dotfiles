#cd to git root
cdgr() {
    # _is_git function from the prompt.bash
    # just bail out if we're not in a git repo
    _is_git || return
    cd $(git rev-parse --show-toplevel)
}
