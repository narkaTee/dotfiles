if v:version < 800
    silent! execute pathogen#infect()
endif
" Load sensible before  the custom settings
runtime! plugin/sensible.vim

source $HOME/.vim/custom/functions.vim
source $HOME/.vim/custom/general-settings.vim
source $HOME/.vim/custom/statusline.vim
source $HOME/.vim/custom/mappings.vim

