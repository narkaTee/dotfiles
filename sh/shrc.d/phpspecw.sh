install_phpspec() {
    composerw require --dev "phpspec/phpspec"
    return $?
}

phpspecw() {
    local vendor="$PWD/vendor"
    local phpspec="$vendor/bin/phpspec"
    if [ ! -d "$vendor" ]; then
        >&2 echo "phpspecw: cannot find vendor dir in PWD!"
        return 1
    fi

    if [ ! -f "$phpspec" ]; then
        echo "phpspecw phpspec not found, trying to install it..."
        if ! install_phpspec; then
            >&2 echo "phpspecw: phpspec failed to install!"
            return 1
        fi
    fi

    if [ ! -x "$phpspec" ]; then
        >&2 echo "phpspecw: $phpspec is not executeable!"
        return 1
    fi

    $phpspec $@
    return $?
}
