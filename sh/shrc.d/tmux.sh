# shellcheck shell=sh
_tmux_auto_attach() {
    if [ "$#" -eq 0 ]; then
        sessions="$("tmux" list-sessions 2> /dev/null)"

        if [ -z "$sessions" ]; then
            num_sessions=0
        else
            lines=$(printf "%s" "$sessions" | wc -l)
            num_sessions="$((lines+1))"
        fi

        if [ "$num_sessions" -eq 0 ]; then
            "tmux"
            return
        fi

        echo "existing sessions:"
        echo
        echo "$sessions"
        echo
        echo "attach to session (new session):"
        # shellcheck disable=SC2162
        read session
        if [ -z "$session" ]; then
            "tmux"
        else
            "tmux" attach -t "$session"
        fi
    else
        "tmux" "$@"
    fi
}

alias tmux=_tmux_auto_attach
alias tmuxs="tmux list-sessions"
