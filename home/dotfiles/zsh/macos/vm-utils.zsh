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

function vmshell() {
  local vm_name="$1"
  local remote_path=$(get_remote_path)
  
  case "$vm_name" in
    nixos)
      ssh -t angel@nixos "cd $remote_path && exec \$SHELL -l"
      ;;
    ubuntu)
      ssh -t parallels@uvm.local "cd $remote_path && exec \$SHELL -l"
      ;;
    *)
      echo "Usage: vmshell [nixos|ubuntu]"
      return 1
      ;;
  esac
}

function vmcode() {
  local vm_name="$1"
  local remote_path=$(get_remote_path)
  local dotfiles_path="/home/angel/.dotfiles"
  
  case "$vm_name" in
    nixos)
      if [[ "$2" == "-d" ]]; then
        code --folder-uri vscode-remote://ssh-remote+angel@nixos$dotfiles_path --new-window
      else
        code --folder-uri vscode-remote://ssh-remote+angel@nixos$remote_path --new-window
      fi
      ;;
    ubuntu)
      if [[ "$2" == "-d" ]]; then
        code --folder-uri vscode-remote://ssh-remote+parallels@uvm.local$dotfiles_path --new-window
      else
        code --folder-uri vscode-remote://ssh-remote+parallels@uvm.local$remote_path --new-window
      fi
      ;;
    *)
      echo "Usage: vmcode [nixos|ubuntu] [-d]"
      return 1
      ;;
  esac
}

function vmcursor() {
  local vm_name="$1"
  local remote_path=$(get_remote_path)
  local dotfiles_path="/home/angel/.dotfiles"
  
  case "$vm_name" in
    nixos)
      if [[ "$2" == "-d" ]]; then
        cursor --folder-uri vscode-remote://ssh-remote+angel@nixos$dotfiles_path --new-window
      else
        cursor --folder-uri vscode-remote://ssh-remote+angel@nixos$remote_path --new-window
      fi
      ;;
    ubuntu)
      if [[ "$2" == "-d" ]]; then
        cursor --folder-uri vscode-remote://ssh-remote+parallels@uvm.local$dotfiles_path --new-window
      else
        cursor --folder-uri vscode-remote://ssh-remote+parallels@uvm.local$remote_path --new-window
      fi
      ;;
    *)
      echo "Usage: vmcursor [nixos|ubuntu] [-d]"
      return 1
      ;;
  esac
}

# ==================================================================================================
# Completions
# ==================================================================================================

# Completion for vmshell
_vmshell() {
    local -a vm_options
    vm_options=('nixos' 'ubuntu')
    _describe 'vm options' vm_options
}
compdef _vmshell vmshell

# Completion for vmcode and vmcursor
_vm_code_cursor() {
    local -a vm_options
    vm_options=('nixos' 'ubuntu')
    _arguments \
        '1:vm options:->vms' \
        '2:dotfiles:(-d)'
    
    case $state in
        vms)
            _describe 'vm options' vm_options
            ;;
    esac
}
compdef _vm_code_cursor vmcode
compdef _vm_code_cursor vmcursor
