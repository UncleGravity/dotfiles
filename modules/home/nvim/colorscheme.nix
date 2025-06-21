{ ... }:

{
  programs.nixvim.colorschemes = {
    kanagawa = {
      enable = true;
      settings = {
        # theme = "dragon";
        compile = true;
        transparent = false;
        commentStyle = {
          italic = false;
          bold = false;
        };
        keywordStyle = {
          italic = false;
          bold = false;
        };
        statementStyle = {
          italic = false;
          bold = false;
        };
        functionStyle = {
          italic = false;
          bold = false;
        };
        typeStyle = {
          italic = false;
          bold = false;
        };
        colors.theme.all.ui.bg_gutter = "none";
      };
    };
  };
}