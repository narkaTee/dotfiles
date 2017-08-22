# Convenience wrapper for chef shell-init.
# it's too damn slow to put it in bash_profile...
chef_init() {
    # run chef shell-init if chef is installed
    if hash chef 2>/dev/null; then
        eval "$(chef shell-init bash)"
    else
        echo "can't find chef executeable!"
        return 1
    fi
}
