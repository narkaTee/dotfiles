
if exists('g:vscode')
    " VSCode mode settings
    " https://github.com/vscode-neovim/vscode-neovim
    let mapleader=" "
    lua << EOF
        vim.g.clipboard = vim.g.vscode_clipboard
        local vscode = require('vscode')
        vim.keymap.set("n", "<leader>o", function()
            vscode.call("workbench.action.quickOpen")
        end)
        vim.keymap.set("n", "<leader>n", function()
            vscode.call("workbench.action.nextEditor")
        end)
        vim.keymap.set("n", "<leader>p", function()
            vscode.call("workbench.action.previousEditor")
        end)
        vim.keymap.set("n", "<leader>d", function()
            vscode.call("editor.action.revealDefinition")
        end)
        vim.keymap.set("n", "<leader>f", function()
            vscode.call("actions.find")
        end)
        vim.keymap.set("v", ">", function()
            vscode.call("editor.action.indentLines")
        end)
        vim.keymap.set("v", "<", function()
            vscode.call("editor.action.outdentLines")
        end)
        vim.keymap.set("n", "<C-b>o", function()
            vscode.call("workbench.action.closeOtherEditors")
        end)
        vim.keymap.set("n", "<C-b>c", function()
            vscode.call("workbench.action.closeActiveEditor")
        end)
EOF
else
    set runtimepath^=~/.vim runtimepath+=~/.vim/after
    let &packpath = &runtimepath
    source ~/.vim/vimrc

endif

set clipboard+=unnamedplus
