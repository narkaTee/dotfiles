# shellcheck shell=sh

if hash fzf 2> /dev/null; then
    __git_fzf_script="$0"

    __git_fzf_list_branches() {
        # Yes column and the parameters are not posix compliant but it will only be run on bash and zsh
        # shellcheck disable=SC3003
        git branch "$@" --color=always --sort=-committerdate --sort=-HEAD --format=$'%(HEAD) %(color:yellow)%(refname:short) %(color:green)(%(committerdate:relative))\t%(color:blue)%(subject)%(color:reset)' | column -ts$'\t'
    }

    case "$1" in
        branches)
            shift
            __git_fzf_list_branches "$@"
            ;;
    esac

    # shellcheck disable=SC2120
    __git_fzf_branches() {
        __git_fzf_list_branches "$@" | fzf \
            -n1 \
            --ansi \
            --color hl:underline,hl+:underline \
            --border-label "Branches" \
            --bind "ctrl-b:reload(\"$__git_fzf_script\" branches -a)" \
            --preview-window down,border-top,40% \
            --preview "git graph --color=always \$(cut -c3- <<< {} | cut -d' ' -f1) --" \
            | sed 's/^\* //' | sed 's/^  origin\///' | awk '{print $1}'
    }

    __git_fzf_branch_switch() {
        git_fzf_target_branch="$(__git_fzf_branches)"
        [ -n "$git_fzf_target_branch" ] && git switch "$git_fzf_target_branch"
    }

    alias gb=__git_fzf_branch_switch
fi
