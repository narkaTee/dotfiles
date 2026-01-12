Guifont SauceCodePro Nerd Font:h11

set title
let &titlestring="%{fnamemodify(getcwd(), ':t')} (%t)"

" shift + ins paste like in the terminal
cnoremap <S-Insert> <C-r>+
nnoremap <S-Insert> "+p
inoremap <S-Insert> <C-r>+

nnoremap <A-1> :GuiTreeviewToggle<CR>
