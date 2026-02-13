# shellcheck shell=bash

_expand_path() {
    local path="$1"
    echo "${path/#\~/$HOME}"
}

_bind_if_exists() {
    local bind_type="$1"
    local path
    path="$(_expand_path "$2")"
    if [ -e "$path" ]; then
        args+=("$bind_type" "$path" "$path")
    fi
}

feature_ro_system() {
    local path
    for path in /usr /lib /lib64 /bin /sbin /home/linuxbrew/.linuxbrew; do
        if [ -e "$path" ]; then
            args+=(--ro-bind "$path" "$path")
        fi
    done

    # Mount some basic system files read-only
    args+=(
        --ro-bind /etc/passwd /etc/passwd
        --ro-bind /etc/group /etc/group
        --ro-bind /etc/hosts /etc/hosts
        --ro-bind /dev/null /proc/cmdline
        --ro-bind /etc/alternatives /etc/alternatives
    )
}

feature_proc() {
    args+=(
        --proc /proc
        --tmpfs /proc/sys
        --tmpfs /proc/1
    )
}

feature_dev_basic() {
    args+=(--dev /dev)
}

feature_tmpfs_tmp() {
    args+=(--tmpfs /tmp)
}

feature_tmpfs_home() {
    args+=(--tmpfs "$HOME")
}

feature_bind_pwd() {
    args+=(--bind "$PWD" "$PWD" --chdir "$PWD")
}

feature_bind_pwd_git_ro() {
    if [ -d "$PWD/.git" ]; then
        args+=(--ro-bind "$PWD/.git" "$PWD/.git")
    fi
}

feature_bind_home() {
    args+=(--bind "$HOME" "$HOME")

    if [ -d "$HOME/bin" ]; then
        args+=(--ro-bind "$HOME/bin" "$HOME/bin")
    fi

    if [ -d "$HOME/.config/git/scripts" ]; then
        args+=(--ro-bind "$HOME/.config/git/scripts" "$HOME/.config/git/scripts")
    fi

    if [ -d "$HOME/.local/share/JetBrains/Toolbox/scripts" ]; then
        args+=(--ro-bind "$HOME/.local/share/JetBrains/Toolbox/scripts" "$HOME/.local/share/JetBrains/Toolbox/scripts")
    fi
}

feature_network() {
    args+=(
        --share-net
        --ro-bind /etc/resolv.conf /etc/resolv.conf
        --ro-bind /etc/ssl/certs /etc/ssl/certs
    )
}

feature_bind_npm_globals() {
    local npm_global_modules

    if command -v npm >/dev/null 2>&1; then
        npm_global_modules="$(npm root -g 2>/dev/null || true)"
        if [ -n "$npm_global_modules" ] && [ -d "$npm_global_modules" ]; then
            args+=(--ro-bind "$npm_global_modules" "$npm_global_modules")
        fi
    fi
}

feature_bind_all_path_dirs() {
    local dir
    local -A seen_dirs

    IFS=':' read -ra path_dirs <<< "$PATH"
    for dir in "${path_dirs[@]}"; do
        if [ -z "$dir" ] || [ -n "${seen_dirs[$dir]:-}" ]; then
            continue
        fi

        seen_dirs[$dir]=1

        if [ -d "$dir" ]; then
            case "$dir" in
                /usr/*|/bin|/sbin|/lib/*|/home/linuxbrew/.linuxbrew/*)
                    ;;
                *)
                    args+=(--ro-bind "$dir" "$dir")
                    ;;
            esac
        fi
    done
}

feature_bind_vim_cfg() {
    bind_ro_if_exists ~/.vim/
}

feature_run_optpl_with_template() {
    if hash optpl 2>/dev/null && [ -n "$(optpl --show-alias "$1")" ]; then
        prepend_cmd+=( "optpl" "$1" )
    fi
}

bind_ro_if_exists() {
    _bind_if_exists --ro-bind "$1"
}

bind_rw_if_exists() {
    _bind_if_exists --bind "$1"
}

bind_cache() {
    local path
    path="$(_expand_path "$1")"
    mkdir -p "$path" 2>/dev/null
    if [ -e "$path" ]; then
        args+=(--bind "$path" "$path")
    fi
}

bind_command_tree() {
    local cmd="$1"
    local levels="${2:-1}"
    shift 2
    local protected_subdirs=("$@")

    local cmd_path
    cmd_path=$(command -v "$cmd" 2>/dev/null) || return

    case "$cmd_path" in
        /usr/*|/bin/*|/sbin/*|/lib/*) return ;;
    esac

    local parent="$cmd_path"
    for ((i=0; i<=levels; i++)); do
        parent=$(dirname "$parent")
    done

    bind_rw_if_exists "$parent"

    local subdir
    for subdir in "${protected_subdirs[@]}"; do
        if [ -d "$parent/$subdir" ]; then
            args+=(--ro-bind "$parent/$subdir" "$parent/$subdir")
        fi
    done
}

add_env() {
    local pattern="$1"
    local name value

    while IFS='=' read -r name value; do
        # we want the pattern to
        # shellcheck disable=SC2254
        case "$name" in
            $pattern)
                args+=(--setenv "$name" "$value")
                ;;
        esac
    done < <(env)
}

feature_essential_env() {
    args+=(
        --setenv HOME "$HOME"
        --setenv USER "${USER:-$(whoami)}"
        --setenv PATH "$PATH"
        --setenv TERM "${TERM:-xterm-256color}"
    )

    if [ -n "$LS_COLORS" ]; then
        args+=(--setenv LS_COLORS "$LS_COLORS")
    fi
}

overlay_mount() {
    local lower_dir="$1"
    local upper_dir="$2"
    local work_dir="$3"
    local mount_point="$4"

    lower_dir="$(_expand_path "$lower_dir")"
    upper_dir="$(_expand_path "$upper_dir")"
    work_dir="$(_expand_path "$work_dir")"
    mount_point="$(_expand_path "$mount_point")"

    mkdir -p "$upper_dir" "$work_dir"

    if [ -e "$lower_dir" ]; then
        args+=(--overlay-src "$lower_dir")
        args+=(--overlay "$upper_dir" "$work_dir" "$mount_point")
    fi
}

_generate_tracking_wrapper() {
    local wrapper_path="$1"
    local before_file="$2"
    local after_file="$3"
    shift 3
    local dirs=("$@")

    local new_commands_file
    new_commands_file="$(dirname "$after_file")/commands.new"

    {
        cat <<'EOF_WRAPPER_START'
#!/usr/bin/env bash
set -euo pipefail

EOF_WRAPPER_START

        echo "BEFORE_FILE=\"$before_file\""
        echo "AFTER_FILE=\"$after_file\""
        echo "NEW_COMMANDS_FILE=\"$new_commands_file\""
        echo ""

        echo "TRACKED_DIRS=("
        for dir in "${dirs[@]}"; do
            echo "    \"$dir\""
        done
        echo ")"
        echo ""

        cat <<'EOF_WRAPPER_END'
"$@"
exit_code=$?

{
    for dir in "${TRACKED_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            find "$dir" -maxdepth 1 \( -type f -o -type l \) 2>/dev/null || true
        fi
    done
} | sort > "$AFTER_FILE"

comm -13 "$BEFORE_FILE" "$AFTER_FILE" > "$NEW_COMMANDS_FILE" || true

if [ -s "$NEW_COMMANDS_FILE" ]; then
    echo ""
    echo "📦 New commands installed:"
    while IFS= read -r cmd; do
        basename "$cmd" | sed 's/^/  - /'
    done < "$NEW_COMMANDS_FILE"
fi

exit $exit_code
EOF_WRAPPER_END
    } > "$wrapper_path"

    chmod +x "$wrapper_path"
}

feature_track_commands() {
    local profile_name="$1"
    shift
    local dirs=("$@")

    local state_dir="$HOME/.cache/boxed/$profile_name"
    mkdir -p "$state_dir"

    local before="$state_dir/commands.before"
    local after="$state_dir/commands.after"

    {
        for dir in "${dirs[@]}"; do
            if [ -d "$dir" ]; then
                find "$dir" -maxdepth 1 \( -type f -o -type l \) 2>/dev/null || true
            fi
        done
    } | sort > "$before"

    local wrapper="$state_dir/wrapper.sh"
    _generate_tracking_wrapper "$wrapper" "$before" "$after" "${dirs[@]}"

    prepend_cmd+=("$wrapper")
}
