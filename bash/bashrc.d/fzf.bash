# shellcheck shell=bash
if hash fzf 2> /dev/null; then
    eval "$(fzf --bash)"

    # this is the event more hideous work (compared to the zsh variant...) of a madman 🫠
    # Based on:
    # - https://github.com/junegunn/fzf/pull/1492
    # - https://github.com/4z3/fzf-plugins/blob/master/history-exec.bash
    # - https://github.com/junegunn/fzf/blob/0420ed4f2a7edcc7f91dc233665f914ce023b7b3/shell/key-bindings.bash
    # - https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html#index-bind

    # setup fzf to always print the key used to accept, we'll act on it in the post processing
    # shellcheck disable=SC2034
    FZF_CTRL_R_OPTS="--expect 'end,enter'"

    # post processing to enable command execution conditionally
    __fzf_rebind_ctrl_x_ctrl_p__() {
        if [[ $READLINE_LINE = "end "* ]] ; then
            READLINE_LINE="${READLINE_LINE/end /}"
            bind '"\C-x\C-p": ""'
        elif [[ $READLINE_LINE = "enter "* ]]; then
            READLINE_LINE="${READLINE_LINE/enter /}"
            bind '"\C-x\C-p": accept-line'
        fi
    }
    # \C-x\C-p is used as a hook to conditionally accept the line or do nothing
    bind '"\C-x\C-p": ""'
    # \C-x\C-o does the post processing and decides if \C-x\C-p should accept the line.
    bind -x '"\C-x\C-o": __fzf_rebind_ctrl_x_ctrl_p__'

    # A whole mess of key seuqnces (try bind -P | grep -i "<key") and try to deceipher it...
    # I could not get the bind -x variant to work because I don't know how to trigger the
    # "accept-line" readline command from the shell-command mode.
    # This works, so good enought for now! until it blows up.
    # shellcheck disable=SC2016
    bind '"\C-r": " \C-e\C-u\C-y\ey\C-u`__fzf_history__`\e\C-e\er\e^\C-x\C-o\C-x\C-p"'
fi
