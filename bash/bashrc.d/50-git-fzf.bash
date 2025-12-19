if hash fzf 2> /dev/null; then
    #bind '"\C-b": "\C-e`__git_fzf_branches`\e\C-e\er"'
    #bind '"\C-b": "\C-k`__git_fzf_branches`\e\C-e\er\C-y"'
    bind '"\C-b":" \C-u \C-a\C-k`__git_fzf_branches`\e\C-e\C-y\C-a\C-y\ey\C-h\C-e\er \C-h"'
fi
