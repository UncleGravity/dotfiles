return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,

  ---@type snacks.Config
  opts = {
    -- Feature toggles -------------------------------------------------------
    bigfile = { enabled = true },          -- Handle large files gracefully
    bufdelete = { enabled = true },        -- Delete buffers without closing windows
    explorer = {
      enabled = true,
      replace_netrw = true,               -- Replace default netrw explorer
    },
    -- indent = { enabled = true },
    picker = { enabled = true },
    quickfile = { enabled = true },
    statuscolumn = { enabled = true },
  },

  -- stylua: ignore
  keys = {
    -- Explorer -------------------------------------------------------------
    -- { "<leader>e",  "<cmd>lua Snacks.explorer()<CR>",               desc = "Open Snacks explorer" },
    { '<leader>e', '<cmd>lua Snacks.explorer()<CR>', { icon = '󰙅', desc = 'Toggle Explorer' } },

    -- Buffer delete --------------------------------------------------------
    { "<leader>bd", "<cmd>lua Snacks.bufdelete()<CR>",              desc = "Delete Buffer" },
    { "<leader>bD", "<cmd>lua Snacks.bufdelete.all()<CR>",          desc = "Delete All Buffers" },
    { "<leader>bo", "<cmd>lua Snacks.bufdelete.other()<CR>",        desc = "Delete Other Buffers" },

    -- Picker --------------------------------------------------------------
    { "<leader><space>", "<cmd>lua Snacks.picker.smart()<CR>",      desc = "Smart Find Files" },
    { "<leader>/",       "<cmd>lua Snacks.picker.grep()<CR>",       desc = "Grep" },
    { "<leader>s\"",   "<cmd>lua Snacks.picker.registers()<CR>",  desc = "Registers" },
    { "<leader>sm",      "<cmd>lua Snacks.picker.marks()<CR>",      desc = "Marks" },
    { "<leader>s/",      "<cmd>lua Snacks.picker.search_history()<CR>", desc = "Search History" },
    { "<leader>s?",      "<cmd>lua Snacks.picker.commands()<CR>",   desc = "Commands" },
    { "<leader>sd",      "<cmd>lua Snacks.picker.diagnostics()<CR>", desc = "Diagnostics" },
    { "<leader>sh",      "<cmd>lua Snacks.picker.help()<CR>",       desc = "Help Pages" },
    { "<leader>sj",      "<cmd>lua Snacks.picker.jumps()<CR>",      desc = "Jumps" },
    { "<leader>sk",      "<cmd>lua Snacks.picker.keymaps()<CR>",    desc = "Keymaps" },

    -- Todo ----------------------------------------------------------------
    { "<leader>sT", "<cmd>lua Snacks.picker.todo_comments()<CR>", desc = "Todo Comments" },
  },
}