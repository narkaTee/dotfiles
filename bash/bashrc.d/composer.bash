# disable xdebug when running composer
function composer() {
    disableXdebug=""
    enableXdebug=""
    if hash php5dismod 2>/dev/null && hash php5enmod 2>/dev/null ; then
        disableXdebug="php5dismod -s cli xdebug"
        enableXdebug="php5enmod -s cli xdebug"
        if [ "$(id -u)" -ne 0 ]; then
            if ! hash sudo 2>/dev/null; then
                echo "We're not root and sudo is not available. Unable to disable xdebug" >&2
            fi
            disableXdebug="sudo ${disableXdebug}"
            enableXdebug="sudo ${enableXdebug}"
        fi
    else
        echo -e "Could not find php5endmod or php5dismod. Unable to disable xdebug" >&2
    fi

    COMPOSER="$(which composer)" || {
        echo "Could not find composer in path" >&2
        return 1
    }

    $disableXdebug
    $COMPOSER "$@"
    STATUS=$?
    $enableXdebug
    return $STATUS
}
