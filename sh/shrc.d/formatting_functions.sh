## COLORS AND FORMATTING
# Output text with terminal ctrl "format" and reset it
_output_with_format() {
    local output="$1" format="$2" reset="\001$(tput sgr0)\002"
    printf "$format$output$reset"
}

# Output test with a color
_apply_color() {
    local output="$1" color="$2"
    color=$(_get_color "$2")
    _output_with_format "$output" "$color"
}

# Get a ansi color and style
_get_color() {
    local color=""
    for part in $1; do
        case "$part" in
            red) color+=$(tput setaf 1) ;;
            green) color+=$(tput setaf 2) ;;
            yellow) color+=$(tput setaf 3) ;;
            blue) color+=$(tput setaf 4) ;;
            pink) color+=$(tput setaf 5) ;;
            cyan) color+=$(tput setaf 6) ;;
            white) color+=$(tput setaf 7) ;;
            gray) color+=$(tput setaf 8) ;;
            bold) color+=$(tput bold) ;;
            reverse) color+=$(tput rev) ;;
            *) printf '_get_color: unknown color or style "%s"' "$1"; return 1 ;;
        esac
    done
    printf "\001$color\002"
}

