# shellcheck shell=bash
manz () {
    local selected_path page
    # we need the expansion of manpath
    # shellcheck disable=SC2046
    selected_path=$(find $(manpath | sed 's/:/ /g') \
        -path '*/man/man1/*' \
        -o -path '*/man/man5*' \
        -o -path '*/man/man8*' \
        -type f | fzf \
        -q "$*" \
        --exact \
        --nth -1 \
        --delimiter "/" \
        --keep-right \
        --preview "man '$(basename {})'"
    )
    [ -z "$selected_path" ] && return

    page="$(basename "$selected_path" '.gz')"
    man "$page"
}
