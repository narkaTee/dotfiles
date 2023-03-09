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

aws_try_login() {
    profile="$1"
    if hash aws-azure-login 2> /dev/null; then
        echo "Trying to log into aws profile '$profile' with aws-azure-login"
        aws-azure-login --no-prompt
    else
        echo "No tooling to perform a login"
    fi
}

alias aws-login='aws_login'
