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

" Always show tab line
set showtabline=2

" set a color column at 80 chars
set colorcolumn=72

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
" enable list mode by default
set list

" no backups
set nobackup
