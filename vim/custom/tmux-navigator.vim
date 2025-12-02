" no wrapping, just press the correct keys dummy
let g:tmux_navigator_no_wrap = 1

" tmux navigator does only add terminal mappings when running in tmux
" I want them always. I'll find out if I need the fzf detection.
let g:tmux_navigator_no_mappings = 1
nnoremap <silent> <c-h> :<C-U>TmuxNavigateLeft<cr>
nnoremap <silent> <c-j> :<C-U>TmuxNavigateDown<cr>
nnoremap <silent> <c-k> :<C-U>TmuxNavigateUp<cr>
nnoremap <silent> <c-l> :<C-U>TmuxNavigateRight<cr>
nnoremap <silent> <c-\> :<C-U>TmuxNavigatePrevious<cr>
tnoremap <expr> <silent> <C-h> "\<C-w>:\<C-U> TmuxNavigateLeft\<cr>"
tnoremap <expr> <silent> <C-j> "\<C-w>:\<C-U> TmuxNavigateDown\<cr>"
tnoremap <expr> <silent> <C-k> "\<C-w>:\<C-U> TmuxNavigateUp\<cr>"
tnoremap <expr> <silent> <C-l> "\<C-w>:\<C-U> TmuxNavigateRight\<cr>"
