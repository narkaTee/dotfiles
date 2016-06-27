# Prep return status variable so we can use arithmetic on it
declare -i CMD_RET
PROMPT_COMMAND='CMD_RET=$?;'
# trim path to 4 elements
PROMPT_DIRTRIM=4

# printe the return code if not zero
_prompt_ret_code() {
    if ((CMD_RET > 0 )); then
        printf '%u ' "$CMD_RET"
    fi
}

# show the number of jobs in curly braces of not zero
_prompt_num_jobs() {
    local -i jobcount

    while read; do
        ((jobcount++))
    done < <(jobs -p)

    if ((jobcount > 0)); then
        printf '{%u}' "$jobcount"
    fi
}

prompt() {
    case $1 in
        on)
            PS1='$(_prompt_ret_code)'
            PS1+='$(_prompt_num_jobs)'
            PS1+='\u@\h:\w# '
        ;;
        off)
            PS1='\u@\h:\w# '
        ;;
        *)
            echo "What?"
            return 1
        ;;
    esac
}

# enable custom prompt
prompt on
