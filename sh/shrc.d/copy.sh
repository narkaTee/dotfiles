# shellcheck shell=bash
copy() {
    # no chunking, just don't copy large stuff
    encoded=$(cat | base64 | tr -d '\n')
    length=$(printf "%s" "$encoded" | wc -c)

    # the maximum payload length _should_ be 100 kB in modern terminals
    # ~8 byte overhead from the osc52 sequence leaves us with 99992
    # bytes/base64-chars payload
    if [ "$length" -gt 99992 ]; then
        echo "Warning: data + osc52 is > 100 kB! Terminal might truncate or ignore copy">&2
    fi

    printf "\033]52;c;%s\a" "$encoded"
}
