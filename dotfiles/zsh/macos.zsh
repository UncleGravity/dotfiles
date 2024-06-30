eval "$(/opt/homebrew/bin/brew shellenv)"

alias vm='prlctl'
alias vmls='prlctl list -a'
alias vmstart='prlctl start ubuntu-2204'
alias vmstop='prlctl stop ubuntu-2204'
alias vmpause='prlctl pause ubuntu-2204'
alias vmresume='prlctl resume ubuntu-2204'
alias vmrestart='prlctl restart ubuntu-2204'
# alias vmshell='ssh parallels@uvm.local'
# alias vmcode='code --remote ssh-remote+parallels@uvm.local --new-window'
# alias vmcode='code --folder-uri vscode-remote://ssh-remote+parallels@uvm.local/media/psf/useradmin/Documents/ios/healthscraper --new-window'

function get_remote_path() {
  local current_local_path="$(pwd)"
  local default_remote_path="~/"
  local common_path_start="/Users/useradmin"
  local remote_base_path="/media/psf/Home"
  
  if [[ $current_local_path == "$common_path_start"* ]]; then
    echo "${remote_base_path}${current_local_path/$common_path_start/}"
  else
    echo "$default_remote_path"
  fi
}

alias remote_path='echo $(get_remote_path)'
alias vmcode='code --folder-uri vscode-remote://ssh-remote+parallels@uvm.local$(get_remote_path) --new-window'
alias vmcursor='cursor --folder-uri vscode-remote://ssh-remote+parallels@uvm.local$(get_remote_path) --new-window'
alias vmshell='ssh -t parallels@uvm.local "cd $(get_remote_path) && exec \$SHELL -l"'
alias vmnix='ssh -t angel@nixos-gnome "cd $(get_remote_path) && exec \$SHELL -l"'
alias code-insiders="/Applications/Visual\ Studio\ Code\ -\ Insiders.app/Contents/Resources/app/bin/code"
alias vmcode-insiders='code-insiders --folder-uri vscode-remote://ssh-remote+parallels@uvm.local$(get_remote_path) --new-window'