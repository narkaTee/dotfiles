syntax on

" Try to use solarized otherwise fallback to desert which is installed on most
" systems
try
    if &t_Co < 256
        throw "not enough colors for solarized"
    endif
    colorscheme solarized
catch
    silent! colorscheme desert
endtry

set background=dark

" enable line numbers
set number

" show commands as I type them
set showcmd

" set a color column at 80 chars
set colorcolumn=72

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
else
    filetype plugin on
endif

set modeline " enable modeline parsing

" show tabs and trailing whitespace as well in list mode
set listchars=tab:>-,trail:~

