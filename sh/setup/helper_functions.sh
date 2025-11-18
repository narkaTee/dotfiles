# shellcheck shell=bash
# I only use bash and zsh so this should be safe enough

# Check for narrow terminal
is_narrow() {
    [ -z "$COLUMNS" ] && [ $COLUMNS -lt 100 ]
}

update_term_title() {
    local pattern="$1"
    # silently try to fetch terminal sequences...
    {
        # shellcheck disable=SC2155
        local tostatus="$(tput tsl)"
        # shellcheck disable=SC2155
        local fromstatus="$(tput fsl)"
    } > /dev/null 2>&1
    if [ -z "$tostatus" ] || [ -z "$fromstatus" ]; then
        if [ -n "$ITERM_SESSION_ID" ]; then
            #... or if iterm is detected use hard coded sequences
            # iterm  supports tsl and fsl but does not supply a
            # termcap file. It uses the xterm file instead which does
            # not contain these caps
            local tostatus='\033]1;'
            local fromstatus='\a'
        else
            #... or return if they are not available
            return;
        fi
    fi
    local user="${USERNAME:-${USER:-$(whoami)}}"
    # shellcheck disable=SC2155
    local host=$(hostname -s 2>/dev/null)

    local formatted="$pattern"
    formatted="${formatted//\\u/$user}"
    formatted="${formatted//\\h/$host}"
    printf "%b%s%b" "$tostatus" "$formatted" "$fromstatus"
}

auto_update_term_tittle() {
    if [ -t 1 ]; then
        if [ -n "$SSH_CONNECTION" ]; then
            update_term_title "\u@\h (ssh)"
        elif [ -n "$SUDO_USER" ]; then
            update_term_title "$SUDO_USER -> \u@\h (sudo)"
        else
            update_term_title "\h (local)"
        fi
    fi
}
