{lib, ...}: {
  programs.nixvim.plugins.which-key = {
    enable = true;
    # Core options mirroring lua plugin (see @which-key.lua)
    settings = {
      preset = "helix";
      defaults = {};
      # Use __raw to inject the same `spec` table as in Lua for group icons & names.
      # This keeps the Nix code short while staying 1-to-1 with the original config.
      spec = [
        {
          __raw = ''
            {
              mode = { 'n', 'v' },
              -- Group icons / names ----------------------------------------------------
              { '<leader>a', group = '[a]i',              icon = { icon = ' ', color = 'azure'  } },
              { '<leader>d', group = '[d]ebug',           icon = { icon = ' ', color = 'red'    } },
              { '<leader>g', group = '[g]it',   mode = { 'n', 'v' }, icon = { icon = ' ', color = 'orange' } },
              { '<leader>l', group = '[l]azy',            icon = { icon = '󰒲 ', color = 'azure'  } },
              { '<leader>q', group = '[q]uit',            icon = { icon = ' ',  color = 'green'  } },
              { '<leader>s', group = '[s]earch',          icon = { icon = ' ',  color = 'azure'  } },
              { '<leader>u', group = '[u]i',              icon = { icon = '󰙵 ', color = 'cyan'   } },
              { '<leader>x', group = 'diagnostics/quickfi[x]', icon = { icon = '󱖫 ', color = 'green' } },
              { '<leader>L', group = '[L]SP',             icon = { icon = ' ', color = 'azure'  } },
              { '<leader>m', group = '[m]arkdown',        icon = { icon = ' ', color = 'azure'  } },
              { '[',         group = 'prev' },
              { ']',         group = 'next' },
              { 'g',         group = 'goto' },
              { 'z',         group = 'fold' },
              {
                '<leader>b',
                group = '[b]uffer',
                icon  = { icon = '󰓩 ', color = 'orange' },
                expand = function()
                  return require('which-key.extras').expand.buf()
                end,
              },
              -- better descriptions ---------------------------------------------------
              { 'gx', desc = 'Open with system app' },
            }
          '';
        }
      ];
    };
  };

  # Keymaps that trigger which-key pop-ups -------------------------------------------
  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "<leader>?";
      action = "<cmd>lua require('which-key').show({ global = false })<cr>";
      options.desc = "Buffer Keymaps";
    }
    {
      mode = "n";
      key = "<c-w><space>";
      action = "<cmd>lua require('which-key').show({ keys = '<c-w>', loop = true })<cr>";
      options.desc = "Window Hydra Mode (which-key)";
    }
  ];
}
