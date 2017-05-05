# Prep return status variable so we can use arithmetic on it
declare -i CMD_RET
PROMPT_COMMAND='CMD_RET=$?;'"${PROMPT_COMMAND}"
# trim path to 4 elements
PROMPT_DIRTRIM=4

# Output text with terminal ctrl "format" and reset it
_output_with_format() {
    local output="$1" format="$2" reset="\001$(tput sgr0)\002"
    printf "$format$output$reset"
}

# Output test with a color
_apply_color() {
    local output="$1" color="$2"
    color=$(_get_color "$2")
    _output_with_format "$output" "$color"
}

# Get a ansi color and style
_get_color() {
    local color=""
    for part in $1; do
        case "$part" in
            red) color+=$(tput setaf 1) ;;
            green) color+=$(tput setaf 2) ;;
            yellow) color+=$(tput setaf 3) ;;
            blue) color+=$(tput setaf 4) ;;
            pink) color+=$(tput setaf 5) ;;
            cyan) color+=$(tput setaf 6) ;;
            white) color+=$(tput setaf 7) ;;
            gray) color+=$(tput setaf 8) ;;
            bold) color+=$(tput bold) ;;
            reverse) color+=$(tput rev) ;;
            *) printf '_get_color: unknown color or style "%s"' "$1"; return 1 ;;
        esac
    done
    printf "\001$color\002"
}

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

# Checks whether this is a git repo
_is_git() {
    [[ -n $(git rev-parse --is-inside-work-tree 2>/dev/null) ]]
}

# Get the upstream status
_git_upstream_status() {
    _is_git || return

    status=""

    local diff="$(git rev-list --count --left-right @{u}...HEAD 2>/dev/null | sed 's/\t/,/g')"
    case "$diff" in
        "") # no upstream or HEAD detached
            ;;
        "0,0") # no divergence
            status="u="
            ;;
        "0,"*) # ahead of upstream
            status="u+${diff#0,}"
            ;;
        *",0") # behind of upstream
            status="u-${diff%,0}"
            ;;
        *) # both
            status="u+${diff#*,}-${diff%,*}"
            ;;
    esac
    printf "$status"
}

# Get repo state
_git_state() {
    _is_git || return

    gitdir="$(git rev-parse --show-toplevel 2>/dev/null)/.git"

    status=""
    if [ -d "$gitdir/rebase-merge" -o -d "$gitdir/rebase-apply" ]; then
        status="rebase"
    elif [ -f "$gitdir/MERGE_HEAD" ]; then
        status="merge"
    elif [ -f "$gitdir/CHERRY_PICK_HEAD" ]; then
        status="cherry-pick"
    fi
    printf "$status"
}

_prompt_git() {
    _is_git || return

    # some fancyness
    printf '┌'

    local branch=$(
        git symbolic-ref -q HEAD 2>/dev/null ||
        git rev-parse --short HEAD 2>/dev/null
    )
    branch=${branch#refs/heads/}
    _apply_color "$branch" "yellow bold"

    upstream=$(_git_upstream_status)
    [ ! -z "$upstream" ] &&
        _apply_color " $upstream" "yellow"

    state=$(_git_state)
    [ ! -z "$state" ] &&
        _apply_color " ($state)" "red"

    # get local repo name
    repopath=$(git rev-parse --show-toplevel 2>/dev/null)
    reponame=${repopath##*/}
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
    printf "└"
}

prompt() {
    local reset="\001$(tput sgr0)\002" \
        green="\001$(tput setaf 2)\002"
    case $1 in
        on)
            _PS1_OLD=$PS1
            PS1="$(_prompt_statusline)"
            PS1+='$(_prompt_git)'
            PS1+='$(_prompt_ret_code)'
            PS1+='\u@\h:'
            PS1+=$green
            PS1+='\w'
            PS1+=$reset
            PS1+='$(_prompt_num_jobs)'
            PS1+='\$ '
        ;;
        off)
            if [ ! -z $_PS1_OLD ]; then
                PS1=$_PS1_OLD
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
    echo "${tostatus}\u@\h${fromstatus}"
}

# enable custom prompt
prompt on
