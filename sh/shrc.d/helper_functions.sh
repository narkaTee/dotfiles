# shellcheck shell=sh
# Check for narrow terminal
_term_is_narrow() {
    [ -z "$COLUMNS" ] && [ $COLUMNS -lt 100 ]
}

