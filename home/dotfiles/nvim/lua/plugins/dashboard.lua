return {
  'goolord/alpha-nvim',
  event = 'VimEnter',
  enabled = true,
  init = false,
  config = function()
    local alpha = require 'alpha'
    local dashboard = require 'alpha.themes.dashboard'
    local v = vim.version()
    local version = ' v' .. v.major .. '.' .. v.minor .. '.' .. v.patch
    local logo = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝
                                                        ]]

    dashboard.section.header.val = vim.split(logo, '\n')
    -- stylua: ignore
    dashboard.section.buttons.val = {
      dashboard.button("f", " " .. " Find file",       "<cmd>Telescope find_files<cr>"),
      dashboard.button("n", " " .. " New file",        [[<cmd> ene <BAR> startinsert <cr>]]),
      dashboard.button("r", " " .. " Recent files",    "<cmd>Telescope oldfiles<cr>"),
      dashboard.button("g", " " .. " Find text",       "<cmd>Telescope live_grep<cr>"),
      dashboard.button("e", "   File Explorer", ":cd $HOME | Neotree<CR>"),
      dashboard.button("c", " " .. " Config",          "<cmd>e $MYVIMRC<cr>"),
      -- dashboard.button("s", " " .. " Restore Session", [[<cmd> lua require("persistence").load() <cr>]]),
      -- dashboard.button("x", " " .. " Lazy Extras",     "<cmd> LazyExtras <cr>"),
      dashboard.button("l", "󰒲 " .. " Lazy",            "<cmd> Lazy <cr>"),
      dashboard.button("q", " " .. " Quit",            "<cmd> qa <cr>"),
    }
    -- for _, button in ipairs(dashboard.section.buttons.val) do
    --   button.opts.hl = 'AlphaButtons'
    --   button.opts.hl_shortcut = 'AlphaShortcut'
    -- end
    -- dashboard.section.header.opts.hl = 'AlphaHeader'
    -- dashboard.section.buttons.opts.hl = 'AlphaButtons'
    -- dashboard.section.footer.opts.hl = 'AlphaFooter'
    -- dashboard.opts.layout[1].val = 8

    local function centerText(text, width)
      width = width or vim.api.nvim_win_get_width(0)  -- Use window width if not provided
      local totalPadding = width - #text
      local leftPadding = math.floor(totalPadding / 2)
      local rightPadding = totalPadding - leftPadding
      return string.rep(' ', leftPadding) .. text .. string.rep(' ', rightPadding)
    end

    -- Send config to alpha
    alpha.setup(dashboard.opts)
    vim.cmd [[autocmd FileType alpha setlocal nofoldenable]] -- Disable folding on alpha buffer

    vim.api.nvim_create_autocmd('User', {
      once = true,
      pattern = 'LazyVimStarted',
      callback = function()
        local stats = require('lazy').stats()
        local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
        local width = vim.api.nvim_win_get_width(0)  -- Get current window width
        dashboard.section.footer.val = {
          centerText(version, width),
          centerText('⚡ Loaded ' .. stats.loaded .. '/' .. stats.count .. ' plugins in ' .. ms .. 'ms', width)
        }
        pcall(vim.cmd.AlphaRedraw)
      end,
    })
  end,
}
