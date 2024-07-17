setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# directioy jumping like in the ide (or like in zsh4humans)
# based on https://github.com/romkatv/zsh4humans/tree/v5
function df-redraw-prompt() {
  for f in chpwd "${chpwd_functions[@]}" precmd "${(@)precmd_functions}"; do
    [[ "${+functions[$f]}" == 0 ]] || "$f" &>/dev/null || true
  done
  zle .reset-prompt
  zle -R
}

function df-cd-rotate() {
  while (( $#dirstack )) && ! pushd -q $1 &>/dev/null; do
    popd -q $1
  done
  if (( $#dirstack )); then
    df-redraw-prompt
  fi
}

function df-cd-back() { df-cd-rotate +1 }
function df-cd-forward() { df-cd-rotate -0 }
function df-cd-up() { builtin cd -q .. && df-redraw-prompt }
function df-cd-down() {
  local dirs=(*(-/N))
  if [ ${#dirs} -eq 0 ] || ! hash fzf 2> /dev/null; then
    return;
  fi
  local opts=(
    --no-clear
    --ansi
    --color=hl:magenta,hl+:magenta
    --walker=dir
    --height=50%
    --border=horizontal
    --no-multi
    --no-mouse
    --tiebreak=length,begin,index
    --exact
  )
  local dir=$(fzf $opts </dev/tty)
  [ -n "$dir" ] && builtin cd -q "$dir"
  df-redraw-prompt
}
zle -N df-cd-back
zle -N df-cd-forward
zle -N df-cd-up
zle -N df-cd-down

bindkey "^[[1;3D" df-cd-back    # Alt+Left: cd into the previous directory
bindkey "^[[1;3C" df-cd-forward # Alt+Right: cd into the next directory
bindkey "^[[1;3A" df-cd-up      # Alt+Up: cd into the parent directory
bindkey "^[[1;3B" df-cd-down    # Alt+Down: cd into a child directory IF fzf is present

alias d='dirs -v'
for index ({1..9}) alias "$index"="cd +${index}"; unset index
