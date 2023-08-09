# uses the sap privileges app to grant the user admin permissions
if [ -e "/Applications/Privileges.app/Contents/Resources/PrivilegesCLI" ]; then
    alias sudo='/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --add ; unalias sudo ; sudo $@'
fi
