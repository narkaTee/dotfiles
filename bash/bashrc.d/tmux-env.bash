#A dirty way to keep env vars up-to-date when re-attaching to a sess
# Drawback: requires one prompt display before env change is effective
if [ ! -z $TMUX ] && hash tmux 2>/dev/null; then
    _refresh_env_from_tmux() {
        if [ ! -z $TMUX ]; then
            export "$(tmux show-environment | grep '^SSH_AUTH_SOCK')"
        fi
    }

    PROMPT_COMMAND="${PROMPT_COMMAND}_refresh_env_from_tmux;"
fi
