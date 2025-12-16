# shellcheck shell=sh
# set PATH to include git-scripts if it exists
if [ -d "$HOME/.config/git/scripts" ]; then
    PATH="$PATH:$HOME/.config/git/scripts"
fi

# Should be the last path modification so it takes precedence
# set PATH to include the private bin if it exists
if [ -d "$HOME/bin" ]; then
    PATH="$HOME/bin:$PATH"
fi

if [ -f "$HOME/.config/setup/env.local.sh" ]; then
    . "$HOME/.config/setup/env.local.sh"
fi

if [ -d "$HOME/.local/share/JetBrains/Toolbox/scripts" ]; then
    # shellcheck disable=SC3028
    case "$OSTYPE" in
        linux*)
            # works around: https://youtrack.jetbrains.com/issue/TBX-4599/Shell-scripts-in-linux-dont-detach
            mkdir -p "$HOME/bin"
            for file in "$HOME"/.local/share/JetBrains/Toolbox/scripts/* ; do
                name="$(basename "$file")"
                if [ -f "$HOME/bin/$name" ]; then
                    continue
                fi
                cat << EOF > "$HOME/bin/$name"
#/usr/bin/env sh
nohup $file "\$@" >/dev/null 2>&1 &
EOF
                chmod +x "$HOME/bin/$name"
            done
            ;;
        *)
            PATH="$PATH:$HOME/.local/share/JetBrains/Toolbox/scripts"
            ;;
    esac
fi
