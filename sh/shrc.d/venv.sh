# shellcheck shell=sh
venv_list() {
    for env in "$HOME/.venv"/*; do
        [ -d "$env" ] || continue
        venvName=$(basename "$env")

        printf "%s" "$venvName"
        if [ "$VIRTUAL_ENV" = "$env" ]; then
            echo " *"
        else
            echo
        fi
    done
}

venv() {
    venvSwitchTo="$1"
    if [ -z "$venvSwitchTo" ]; then
        if [ ! -d "$HOME/.venv/" ]; then
            # shellcheck disable=SC2088
            echo "~/.venv does not exist, create a venv with: python3 -m venv ~/.venv/<env name>"
            return
        fi

        venv_list
    else
        if [ ! -d "$HOME/.venv/$venvSwitchTo" ]; then
            echo "no such venv: $venvSwitchTo"

            echo "available:"
            venv_list

            echo
            echo "Or create it with: python3 -m venv ~/.venv/$venvSwitchTo"
            return
        fi

        if [ ! -f "$HOME/.venv/$venvSwitchTo/bin/activate" ]; then
            echo "no activate script found in $HOME/.venv/$venvSwitchTo/bin/activate"
            return 1
        fi

        . "$HOME/.venv/$venvSwitchTo/bin/activate"
        echo "Activated $venvSwitchTo venv"
    fi

}
