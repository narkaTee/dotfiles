#A dirty way to keep env vars up-to-date when re-attaching to a sess
# Drawback: requires one prompt display before env change is effective
if [ ! -z $TMUX ] && hash tmux 2>/dev/null; then
    _refresh_env_from_tmux() {
        if [ -z $TMUX ]; then
            # bail out for no tmux running
            return;
        fi

        local tmux_env="$(tmux show-environment | grep '^SSH_AUTH_SOCK')"
        if [ ! -z "$tmux_env" ]; then
            export "$tmux_env"
        fi
    }

    PROMPT_COMMAND="${PROMPT_COMMAND}_refresh_env_from_tmux;"
fi
