install_phpunit() {
    composerw require --dev "phpunit/phpunit"
    return $?
}

phpunitw() {
    local vendor="$PWD/vendor"
    local phpunit="$vendor/bin/phpunit"
    if [ ! -d "$vendor" ]; then
        >&2 echo "phpunitw: cannot find vendor dir in PWD!"
        return 1
    fi

    if [ ! -f "$phpunit" ]; then
        echo "phpunitw: phpunit not found, trying to install it..."
        if ! install_phpunit; then
            >&2 echo "phpunitw: phpunit failed to install!"
            return 1
        fi
    fi

    if [ ! -x "$phpunit" ]; then
        >&2 echo "phpunitw: $phpunit is not executeable!"
        return 1
    fi

    $phpunit $@
    return $?
}
