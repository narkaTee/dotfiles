# Prep return status variable so we can use arithmetic on it
declare -i CMD_RET
PROMPT_COMMAND='CMD_RET=$?;'"${PROMPT_COMMAND}"
# trim path to 3 elements
PROMPT_DIRTRIM=3

# print the return code if not zero
_prompt_ret_code() {
    if ((CMD_RET > 0 )); then
        _apply_color "$CMD_RET " "red bold"
    fi
}

# show the number of jobs in curly braces of not zero
_prompt_num_jobs() {
    local -i jobcount

    while read; do
        ((jobcount++))
    done < <(jobs -p)

    if ((jobcount > 0)); then
        printf '[%u]' "$jobcount"
    fi
}

_prompt_git() {
    _is_git || return

    # some fancyness
    printf '┌'

    branch=$(_prompt_git_branch)
    _apply_color "$branch" "yellow bold"

    upstream=$(_prompt_git_upstream_status)
    [ ! -z "$upstream" ] &&
        _apply_color " $upstream" "yellow"

    state=$(_prompt_git_state)
    [ ! -z "$state" ] &&
        _apply_color " ($state)" "red"

    # get local repo name
    reponame=$(_prompt_git_reponame)
    [ ! -z "$reponame" ] &&
        _apply_color " $reponame" "blue bold"

    # WD dirty
    if ! git diff --quiet 2>/dev/null; then
        _apply_color " *" "red"
    elif ! git diff --staged --quiet 2>/dev/null; then
        _apply_color " *" "yellow"
    fi

    # stash dirty
    git rev-parse --verify refs/stash >/dev/null 2>/dev/null &&
        _apply_color " $" "red"

    # bash won't print the NL if there are no chars after it.
    #  To work around this and not mess up the bash prompt length
    #  we'll just append the 'non-printable' markers behind it...
    printf "\n\001\002"
    # some fancyness
    if _term_is_narrow; then
        printf "├"
    else
        printf "└"
    fi
}

# The prompt can get very cramped on a narrow terminal.
# let's try to get some room by putting the prompt to the next line
_promp_small_term_nl() {
    if ! _term_is_narrow; then
        return
    fi

    if [ $_GIT_SLOW = 'no'  ]; then
        printf "\n└"
    else
        printf "\n\001\002"
    fi
}

prompt() {
    local reset="\001$(tput sgr0)\002" \
        green="\001$(tput setaf 2)\002"
    case $1 in
        on)
            _PS1_OLD=$PS1
            _GIT_SLOW="no"
            local git_speed=$(_prompt_git_speed)

            # the value should be around 2-10ms on a performant system
            if [[ $git_speed -gt 80 ]]; then
                _GIT_SLOW="yes"
                _GIT_SPEED="$git_speed ms"
            fi

            PS1="$(_prompt_statusline)"
            # If git is slow skip the git prompt.
            # Can be the case on: raspberry pi, cygwin + BLODA
            if [ $_GIT_SLOW = 'no'  ]; then
                PS1+='$(_prompt_git)'
            fi
            PS1+='$(_prompt_ret_code)'
            PS1+='\u@\h:'
            PS1+=$green
            PS1+='\w'
            PS1+=$reset
            PS1+='$(_promp_small_term_nl)'
            PS1+='$(_prompt_num_jobs)'
            PS1+='\$ '
        ;;
        off)
            if [ ! -z "$_PS1_OLD" ]; then
                PS1="$_PS1_OLD"
                return
            fi
            PS1='\u@\h:\w\$ '
        ;;
        *)
            echo "What?"
            return 1
        ;;
    esac
}

_prompt_statusline() {
    # silently try to fetch terminal sequences...
    {
        local tostatus="$(tput tsl)"
        local fromstatus="$(tput fsl)"
    } > /dev/null 2>&1
    #... and return if they are not available
    if [ -z $tostatus ] || [ -z $fromstatus ]; then
        return;
    fi
    echo "\001${tostatus}\u@\h${fromstatus}\002"
}

# enable custom prompt
prompt on
