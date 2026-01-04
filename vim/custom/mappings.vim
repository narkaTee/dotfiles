" Map F3 to toggle line numbers in normal and insert mode
:nnoremap <F3> :set invnumber<CR>
:inoremap <F3> <C-O>:set invnumber <CR>

" set pastegoggle to <F2>
set pastetoggle=<F2>

" jump through history
nnoremap <A-Left> <C-o>
nnoremap <A-Right> <C-i>
" terminal emulators do not send alt keys
nnoremap <Esc>[1;3D <C-o>
nnoremap <Esc>[1;3C <C-i>

nnoremap <Leader>n :bnext<CR>
nnoremap <Leader>p :bprev<CR>
nnoremap <C-b>o :%bdelete\|edit #\|normal `"<CR>
nnoremap <C-b>c :bd<CR>

" easier indentation
vnoremap < <gv
vnoremap > >gv
