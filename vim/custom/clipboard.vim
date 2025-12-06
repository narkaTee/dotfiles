augroup Osc52Yank
    autocmd!
    autocmd TextYankPost * call s:Osc52Copy(v:event)
augroup END

function! s:Osc52Copy(event) abort
    if a:event.regname !~# '^[A-Za-z]$'
        return
    endif

    let l:encoded = base64_encode(str2blob(a:event.regcontents))
    let l:osc = "\e]52;c;" . l:encoded . "\x07"
    if len(l:osc) > 100000
        echom 'Warning: data + osc52 is >100kB! Terminal might truncate or ignore copy'
    endif

    call writefile(str2blob([l:osc]), '/dev/tty', 'b')
endfunction
