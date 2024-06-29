if hash fzf 2> /dev/null; then
  source <(fzf --zsh)

  # this is the hideous work of a madman 🫠
  # based on:
  #  - The original keybindings from fzf: https://github.com/junegunn/fzf/blob/0420ed4f2a7edcc7f91dc233665f914ce023b7b3/shell/key-bindings.zsh#L108-L133
  #  - this issue: https://github.com/junegunn/fzf/issues/477
  #  - these dotfile: https://github.com/nhooyr/dotfiles/blob/92623b7a3e9fa421d191f6c2bb77de4ce60aa367/zsh/fzf.zsh#L48-L61
  #  - and https://unix.stackexchange.com/questions/29724/how-to-properly-collect-an-array-of-lines-in-zsh
  #
  # The desired behaviour is it should behave like th original reverse search: enter execute result without editing
  # To edit the line before executing end can be pressed
  fzf_history() {
    local selected num
    setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null
    FZF_CTRL_R_OPTS="$FZF_CTRL_R_OPTS --expect=end"
    if zmodload -F zsh/parameter p:history 2>/dev/null && (( ${#commands[perl]} )); then
      selected=("${(@f)$(printf '%1$s\t%2$s\000' "${(vk)history[@]}" |
        perl -0 -ne 'if (!$seen{(/^\s*[0-9]+\**\s+(.*)/, $1)}++) { s/\n/\n\t/gm; print; }' |
        FZF_DEFAULT_OPTS=$(__fzf_defaults "" "-n2..,.. --scheme=history --bind=ctrl-r:toggle-sort --highlight-line ${FZF_CTRL_R_OPTS-} --query=${(qqq)LBUFFER} +m --read0") \
        FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd))}")
    else
      selected=("${(@f)$(fc -rl 1 | awk '{ cmd=$0; sub(/^[ \t]*[0-9]+\**[ \t]+/, "", cmd); if (!seen[cmd]++) print $0 }' |
        FZF_DEFAULT_OPTS=$(__fzf_defaults "" "-n2..,.. --scheme=history --bind=ctrl-r:toggle-sort --highlight-line ${FZF_CTRL_R_OPTS-} --query=${(qqq)LBUFFER} +m") \
        FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd))}")
    fi
    if [[ "$selected" ]]; then
      local edit=0
      if [[ $selected[1] = 'end' ]]; then
        edit=1
        shift selected
      fi
      if num=$(awk '{print $1; exit}' <<< "$selected" | grep -o '^[1-9][0-9]*'); then
        zle vi-fetch-history -n $num
      else
        LBUFFER="$selected"
      fi
      [[ $edit = 0 ]] && zle accept-line
    fi
    zle reset-prompt
  }
  zle -N fzf-history fzf_history
  bindkey "^R" fzf-history
fi
