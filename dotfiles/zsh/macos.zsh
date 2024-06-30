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

function vmshell() {
  local vm_name="$1"
  local remote_path=$(get_remote_path)
  
  case "$vm_name" in
    nixos)
      ssh -t angel@nixos-gnome "cd $remote_path && exec \$SHELL -l"
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
        code --folder-uri vscode-remote://ssh-remote+angel@nixos-gnome$dotfiles_path --new-window
      else
        code --folder-uri vscode-remote://ssh-remote+angel@nixos-gnome$remote_path --new-window
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
        cursor --folder-uri vscode-remote://ssh-remote+angel@nixos-gnome$dotfiles_path --new-window
      else
        cursor --folder-uri vscode-remote://ssh-remote+angel@nixos-gnome$remote_path --new-window
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