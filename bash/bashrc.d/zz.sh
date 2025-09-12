# shellcheck shell=bash
function zz() {
    query="$*"
    queryParam=""
    if [ -n "$query" ]; then
        queryParam="-q $query"
    fi
    # shellcheck disable=SC2086
    targetDir=$(z | fzf -n2 --scheme path --tiebreak length,index $queryParam | tr -s ' ' | cut -d ' ' -f 2)
    [ -n "$targetDir" ] && cd "$targetDir" || return
}
