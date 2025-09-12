# shellcheck shell=sh
# uses the sap privileges app to grant the user admin permissions
if [ -e "/Applications/Privileges.app/Contents/Resources/PrivilegesCLI" ]; then

    # shellcheck disable=SC2142
    alias sudo='/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --add ; unalias sudo ; sudo $@'
fi
