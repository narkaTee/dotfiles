function zz() {
    query="$@"
    queryParam=""
    if [ -n "$query" ]; then
        queryParam="-q $query"
    fi
    targetDir=$(z | fzf -n2 --scheme path --tiebreak length,index $queryParam | tr -s ' ' | cut -d ' ' -f 2)
    [ -n "$targetDir" ] && cd "$targetDir"
}
