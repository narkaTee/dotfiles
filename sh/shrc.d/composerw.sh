install_composer() {
    local install_dir="$1"
    local setup_php="${install_dir}/composer-setup.php"

    local EXPECTED_SIGNATURE=$(wget -q -O - https://composer.github.io/installer.sig)
    php -r "copy('https://getcomposer.org/installer', '$setup_php');"
    local ACTUAL_SIGNATURE=$(php -r "echo hash_file('SHA384', '$setup_php');")

    if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]
    then
	>&2 echo 'composerw: Error: Invalid installer signature'
	rm "$setup_php"
	return 1
    fi

    php "$setup_php" --quiet --install-dir "${install_dir}"
    local RESULT=$?
    rm "$setup_php"
    return $RESULT
}

composerw() {
    local user_bin="$HOME/bin"
    local composer="$user_bin/composer.phar"

    if [ ! -d "$user_bin" ]; then
        >&2 echo "composerw: $user_bin does not exist!"
        return 1
    fi

    if [ ! -f "$composer"  ] 2>/dev/null; then
        # composer does not exist
        echo 'composerw: composer not found, installing...'
        if ! install_composer "$user_bin"; then
            >&2 echo "composerw: there was an error installing composer!"
            return 1
        fi
    fi

    $composer $@
    status=$?
    return $status
}
