{lib, ...}: {
  programs.nixvim.plugins.gitsigns = {
    enable = true;
    settings = {
      signs = {
        add.text = "▎";
        change.text = "▎";
        delete.text = "";
        topdelete.text = "";
        changedelete.text = "▎";
        untracked.text = "▎";
      };

      signs_staged = {
        add.text = "▎";
        change.text = "▎";
        delete.text = "";
        topdelete.text = "";
        changedelete.text = "▎";
      };

      on_attach.__raw = ''
        function(bufnr)
          local gs = package.loaded.gitsigns

          local function map(mode, l, r, desc)
            vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
          end

          -- Navigation
          map('n', ']h', gs.next_hunk, 'Next Hunk')
          map('n', '[h', gs.prev_hunk, 'Prev Hunk')

          -- Actions
          map('n', '<leader>gs', gs.stage_hunk, 'Stage hunk')
          map('v', '<leader>gs', function()
            gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
          end, 'Stage hunk')

          -- TODO: add confirmation to resetting hunks and buffers
          map('n', '<leader>gr', gs.reset_hunk, 'Reset hunk')
          map('v', '<leader>gr', function()
            gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
          end, 'Reset hunk')

          map('n', '<leader>gS', gs.stage_buffer, 'Stage buffer')
          map('n', '<leader>gR', gs.reset_buffer, 'Reset buffer')

          map('n', '<leader>gu', gs.undo_stage_hunk, 'Undo stage hunk')

          map('n', '<leader>gp', gs.preview_hunk_inline, 'Preview hunk')

          map('n', '<leader>gb', function()
            gs.blame_line { full = true }
          end, 'Blame line')
          map('n', '<leader>gB', gs.toggle_current_line_blame, 'Toggle line blame')

          map('n', '<leader>gd', gs.diffthis, 'Diff this')
          map('n', '<leader>gD', function()
            gs.diffthis '~'
          end, 'Diff this ~')

          -- Toggle word diff
          map('n', '<leader>gw', gs.toggle_word_diff, 'Toggle word diff')

          -- Text object
          map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', 'Gitsigns select hunk')
        end
      '';
    };
  };
}
