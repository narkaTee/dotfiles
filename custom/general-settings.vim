syntax on
colorscheme solarized
set background=dark

set number " enable line numbers

" replace tabs with spaces
set expandtab
" replace tab with 4 space
set softtabstop=4
" indent by 4 spaces when using ident operations
set shiftwidth=4
" round indentations up to multiples of shiftwidth
" for example 2 spaces will be rounded up to 4 spaces or down to 0
set shiftround

if has("autocmd")
  filetype plugin indent on " enable filetype plugin and indent
endif

set modeline " enable modeline parsing

