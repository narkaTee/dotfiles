let g:ale_completion_enabled = 1
let g:ale_fix_on_save = 1
let g:ale_set_quickfix = 1

noremap <Leader>d :call ALEGoToDefOrTags()<CR>
noremap <Leader>q :ALEHover<CR>

function! ALEGoToDefOrTags() abort
    let l:buf = bufnr('%')
    let l:ln = line('.')
    execute 'ALEGoToDefinition'
    if bufnr('%') == l:buf && line('.') == l:ln
        execute 'Tags' expand('<cword>')
    endif
endfunction
