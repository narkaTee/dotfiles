
set laststatus=2

set statusline=%f	" path of file
set statusline+=\ \ \ 	" some whitespace

set statusline+=[
set statusline+=%{&ff}	" file format
set statusline+=,%{strlen(&fenc)?&fenc:'none'}	" file encoding
set statusline+=]

set statusline+=\ %y	" filetype
set statusline+=\ %m	" modified
set statusline+=\ %r	" readonly

set statusline+=%{PasteModeStatus()}    " Paste mode status

set statusline+=%=	" seperator (left/right)
set statusline+=%{getcwd()}\ \ \ 	" CWD
set statusline+=%-10.(%l,%c%V%)\ %p%%/%L	" line,column  %/num lines

