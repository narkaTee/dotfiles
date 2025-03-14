aws_login() {
    if [ -n "$1" ]; then
        export AWS_PROFILE="$1"
    fi
    profile="${AWS_PROFILE:-default}"

    if aws_valid_credentials; then
        echo "Switched to '$profile', credentials valid"
    else
        echo "Swithed to '$profile', trying to log in..."
        aws_try_login "$profile"
    fi
}

aws_valid_credentials() {
    aws sts get-caller-identity > /dev/null 2>&1
}

aws_profile_contains_key_starting_with() {
    profile="$1"
    prefix="$2"
    config_file="${AWS_CONFIG_FILE:-$HOME/.aws/config}"

    if grep -q "^\[profile $profile\]" "$config_file"; then
        awk -v profile="[profile $profile]" -v prefix="$prefix" '
        # Check if the current line matches the profile
        $0 == profile {
            in_profile = 1;
            next
        }
        # Check if the current line is a new profile section
        /^\[.*\]/ {
            in_profile = 0
        }
        # Check if the current line within the profile starts with the prefix
        in_profile && $0 ~ "^" prefix {
            found = 1;
            exit
        }
        # Exit with the appropriate status based on whether the prefix was found
        END {
            exit !found
        }
        ' "$config_file"
    else
        return 1
    fi
}

aws_use_azure_login_for_profile() {
    aws_profile_contains_key_starting_with "$1" "azure_" \
        && hash aws-azure-login 2> /dev/null
}

aws_use_sso_for_profile() {
    aws_profile_contains_key_starting_with "$1" "sso_"
}

aws_try_login() {
    profile="$1"
    if aws_use_sso_for_profile "$profile"; then
        echo "Trying to log in aws profile '$profile' with aws sso"
        aws sso login
    elif aws_use_azure_login_for_profile "$profile"; then
        echo "Trying to log into aws profile '$profile' with aws-azure-login"
        aws-azure-login --no-prompt
    else
        echo "No tooling to perform a login"
    fi
}

alias aws-login='aws_login'
