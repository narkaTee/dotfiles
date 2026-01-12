" netrw settings
let g:netrw_winsize = 30

if !exists('g:GuiLoaded')
  " alt+1 causes esc+1 to be sent by the terminal emulator
  nnoremap <Esc>1 :Lexplore<CR>
  nnoremap <A-1> :Lexplore<CR>
endif
