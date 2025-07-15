{pkgs, ...}: let
  bat = "${pkgs.bat}/bin/bat";
in {
  programs.bat.enable = true;

  home.sessionVariables = {
    BAT_PAGER = "less -RF --mouse"; # Fix "bat" issue where mouse scroll doesn't work in tmux
    MANPAGER = "sh -c 'col -bx | ${bat} -l man -p'"; # Colorize man pages (with bat)
    MANROFFOPT = "-c"; # Fix man page formatting issue
  };

  home.shellAliases."cat" = "${bat}";

  programs.zsh.shellGlobalAliases = {
    "--help" = "--help | ${bat} --language=help --style=plain --paging=never"; # Syntax highlighting for all help commands (e.g. `ls --help`)
  };
}
