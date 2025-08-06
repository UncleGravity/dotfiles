#!/usr/bin/env zsh
#
# ==================================================================================================
# FZF - Dashboard
# ==================================================================================================
# tldr: Press ctrl + f to search for files, directories, grep, and tmux.
# in case i forget the keybindings

# Helper functions
_fzf_select_mode() {
  echo -e "grep\ntmux\nprojects\ndotfiles\ngh" | fzf --prompt="Select search mode: " --height=~50% --tmux --layout=reverse --border
}

# Fuzzy
_fzf_grep() {
  rg --hidden --color=always --line-number --no-heading --smart-case "" \
    --glob '!{node_modules,dist,build,.git}/**' \
    --glob '!*.{lock,min.js}' |
    fzf --ansi \
      --height=80% \
      --tmux 80% \
      --color "hl:-1:underline,hl+:-1:underline:reverse" \
      --delimiter : \
      --preview 'bat --color=always {1} --highlight-line {2}' \
      --preview-window 'right:66%,border-left,+{2}+3/3,~3' \
      --bind 'ctrl-/:change-preview-window(down|hidden|)'
}

_fzf_tmux() {
  local tmux_mode=$(echo -e "commands\nkeybindings" | fzf --prompt="Select tmux mode: " --height=~50% --tmux --layout=reverse --border)
  [[ -z $tmux_mode ]] && return

  case $tmux_mode in
  commands)
    tmux list-commands |
      fzf --ansi \
        --height=80% \
        --tmux 80% \
        --preview 'tmux list-commands {1} | bat --color=always --language=sh' \
        --preview-window 'down:20%' \
        --bind 'ctrl-/:change-preview-window(down|hidden|)' |
      cut -d' ' -f1
    ;;
  keybindings)
    tmux list-keys |
      awk '{$1=""; $2=""; print $0}' |
      sed 's/^  *//' |
      fzf --ansi \
        --height=80% \
        --tmux 80% \
        --preview 'echo {} | bat --color=always --language=sh' \
        --preview-window 'down:20%' \
        --bind 'ctrl-/:change-preview-window(down|hidden|)'
    ;;
  esac
}

_select_editor() {
  echo -e "nvim\ncode\ncursor" | fzf --prompt="Select an editor: " --height=~50% --tmux 80% --layout=reverse --border
}

# export DOTFILES_DIR="$HOME/Documents/.dotfiles"

_fzf_projects() {
  local projects_command="fd -t d -H '^.git$' ~/Documents $(test -d /media/psf/Home/Documents && echo /media/psf/Home/Documents) -x echo {//}"

  local project_dir=$(
    eval "$projects_command" |
      fzf --prompt="Select project: " \
        --height=~50% \
        --tmux 80% \
        --layout=reverse \
        --border
  )

  if [[ -z $project_dir ]]; then
    return 1
  fi

  local action=$(echo -e "cursor\nvscode\nnvim\ntmux" |
    fzf --prompt="Open with: " --height=~50% --tmux --layout=reverse --border)

  if [[ -z $action ]]; then
    return 1
  fi

  case $action in
  cursor) echo "cursor \"$project_dir\"" ;;
  vscode) echo "code \"$project_dir\"" ;;
  nvim) echo "nvim \"$project_dir\"" ;;
  tmux)
    local session_name=$(basename "$project_dir")
    if [ -n "$TMUX" ]; then
      # If already in a tmux session, create a new session and switch to it
      tmux new-session -A -d -s "$session_name" -c "$project_dir"
      tmux switch-client -t "$session_name"
    else
      # If not in a tmux session, create a new session and attach to it
      tmux new-session -A -s "$session_name" -c "$project_dir"
    fi
    ;;
  esac
}

_fzf_dotfiles() {
  local action=$(echo -e "cursor\nnvim\ntmux" |
    fzf --prompt="Open dotfiles with: " --height=~50% --tmux --layout=reverse --border)

  if [[ -z $action ]]; then
    return 1
  fi

  case $action in
  cursor) echo "cursor \"$DOTFILES_DIR\"" ;;
  nvim) echo "nvim \"$DOTFILES_DIR\"" ;;
  tmux)
    local session_name="_dotfiles"
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
      tmux new-session -d -s "$session_name" -c "$DOTFILES_DIR"
      tmux send-keys -t "$session_name" 'nvim .' C-m
    fi
    if [ -z "$TMUX" ]; then
      tmux attach-session -t "$session_name"
    else
      tmux switch-client -t "$session_name"
    fi
    return 0
    ;;
  esac
}

_fzf_gh() {
  local username=$(gh api user --jq '.login')

  local org=$(printf "%s\n%s\n" "$username" "$(gh api user/orgs --jq '.[].login')" |
    fzf --prompt="Select organization: " --height=~50% --tmux --layout=reverse --border)
  [[ -z $org ]] && return 1

  local repos=$(gh repo list "$org" --limit 1000 --json name,nameWithOwner,description,isFork,url \
    --jq '.[] | "\(.name)\t\(.nameWithOwner)\t\(.description)\t\(.isFork)\t\(.url)"')

  local repo=$(echo "$repos" |
    awk -F'\t' '{print ($4 == "true" ? "* " : "  ") $1 "\t" $2 "\t" $3 "\t" $5}' |
    fzf --prompt="Select repository: " \
      --height=80% \
      --tmux 80% \
      --layout=reverse \
      --border \
      --with-nth=1,2 \
      --preview 'echo {3}' \
      --preview-window=down:3:wrap \
      --delimiter='\t' \
      --bind="ctrl-/:change-preview-window(down|hidden|)" \
      --bind="ctrl-y:execute-silent(echo -n {4} | cb copy)+abort" \
      --header="CTRL-Y: Copy repo URL" \
      --color 'fg:188,fg+:222,bg+:#3a3a3a,hl+:104' \
      --color 'pointer:161,info:144,spinner:135,header:61,prompt:214' \
      --color 'marker:118,border:248')
  [[ -z $repo ]] && return 1

  local repo_name=$(echo "$repo" | cut -f2)
  local repo_local_name=$(echo "$repo_name" | cut -d'/' -f2)

  echo "gh repo clone $repo_name -- --recursive && cd $repo_local_name"
}

# Main function
fuzzy-files() {
  local mode=$(_fzf_select_mode)
  [[ -z $mode ]] && return

  local result=""
  case $mode in
  grep)
    local selected=$(_fzf_grep)
    if [[ -n $selected ]]; then
      local file=$(echo $selected | cut -d':' -f1)
      local line=$(echo $selected | cut -d':' -f2)
      local editor=$(_select_editor)
      [[ -z $editor ]] && return

      case $editor in
      nvim) result="nvim +$line $file" ;;
      code) result="code -g $file:$line" ;;
      cursor) result="cursor -g $file:$line" ;;
      esac
    fi
    ;;
  tmux)
    result=$(_fzf_tmux)
    ;;
  projects)
    result=$(_fzf_projects)
    ;;
  dotfiles)
    result=$(_fzf_dotfiles)
    ;;
  gh)
    result=$(_fzf_gh)
    ;;
  esac

  if [[ -n $result ]]; then
    BUFFER="$result"
    zle redisplay
    zle accept-line # This line will submit the command
  fi
  zle reset-prompt
}

zle -N fuzzy-files
bindkey '^F' fuzzy-files
