# shellcheck shell=bash
__tldr_cache="$HOME/.config/tldr/repo"
__tldr_pages="$__tldr_cache/pages"
__tldr_script="${BASH_SOURCE[0]}"

tldr_update() {
    if [ ! -d "$__tldr_cache" ]; then
        mkdir -p "$__tldr_cache"
    fi

    if [ ! -d "$__tldr_cache/.git" ]; then
        git clone --depth=1 https://github.com/tldr-pages/tldr "$__tldr_cache"
    else
        cd "$__tldr_cache" || exit
        git pull
    fi
}

if [ ! -t 0 ]; then
    # stdin not connected to terminal, means we are beeing piped to
    cat | \
    sed "
        s/^# \(.*\)$/\x1b[1;33m\1\x1b[0m/;
        s/^> \(.*\)$/\x1b[3m\1\x1b[0m/;
        s/^- \(.*\)$/\x1b[3;37m• \1\x1b[0m/;
        s/^\`\([^\`]*\)\`$/  \x1b[34m\1\x1b[0m/;
        "
fi

# --preview "sed 's/^# //; s/^> //' '$__tldr_pages/{1}'" \
tldr() {
    if [ ! -d "$__tldr_pages" ]; then
        echo "tldr pages cache not found, updating..."
        tldr_update
    fi
    find "$__tldr_pages" -name '*.md' \
        | sed "s#^$__tldr_pages/##" \
        | fzf \
            --scheme path --tiebreak=end,pathname,length \
            -q "$*" \
            --preview "cat '$__tldr_pages/{1}' | $__tldr_script" \
            --bind "enter:execute(cat $__tldr_pages/{1} | $__tldr_script | less -r)"
}
