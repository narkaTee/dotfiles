"probe some location to look for the fzf vim extension
let s:fzf_paths = [
      \ '~/.fzf/plugin/fzf.vim',
      \ '/usr/share/doc/fzf/examples/plugin/fzf.vim',
      \ '/home/linuxbrew/.linuxbrew/opt/fzf/plugin/fzf.vim',
      \ '/opt/homebrew/opt/fzf/plugin/fzf.vim',
      \ '/usr/local/opt/fzf/plugin/fzf.vim',
      \ '/usr/share/vim/vimfiles/plugin/fzf.vim',
      \ ]

for p in s:fzf_paths
  let p = expand(p)
  if filereadable(p)
    execute 'source ' . fnameescape(p)
    break
  endif
endfor

nnoremap <silent> <leader>o :FZF<CR>
nnoremap <silent> <leader>f :BLines<CR>
nnoremap <silent> <leader>b :Buffers<CR>
