return {
  'mfussenegger/nvim-dap',
  lazy = true,
  dependencies = {
    -- Python
    {
      'mfussenegger/nvim-dap-python',
      lazy = true,
      config = function()
        require('dap-python').setup()
      end,
    },
    -- Go
    {
      'leoluz/nvim-dap-go',
      lazy = true,
      config = function()
        require('dap-go').setup()
      end,
    },
    -- Fancy UI
    {
      'rcarriga/nvim-dap-ui',
      lazy = true,
      keys = {
        {
          '<leader>de',
          function()
            -- Calling this twice to open and jump into the window.
            require('dapui').eval()
            require('dapui').eval()
          end,
          desc = 'Evaluate expression',
        },
      },
      opts = {
        floating = { border = 'rounded' },
        -- layouts = {
        --   {
        --     elements = {
        --       { id = 'stacks', size = 0.30 },
        --       { id = 'breakpoints', size = 0.20 },
        --       { id = 'scopes', size = 0.50 },
        --     },
        --     position = 'left',
        --     size = 40,
        --   },
        -- },
      },
      dependencies = { 'nvim-neotest/nvim-nio' },
    },
    -- Virtual text.
    {
      'theHamsta/nvim-dap-virtual-text',
      lazy = true,
      opts = { virt_text_pos = 'eol' },
    },
  },

  -----------------------------------------------------------------------------------------------
  -- Keymaps
  -- stylua: ignore
  keys = {
    -- normal mode is default
    { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = 'Toggle breakpoint' },
    { '<leader>dc', function() require('dap').continue() end, desc = 'Continue' },
    { "<leader>dn", function() require('dap').step_over() end, desc = 'Step over (next)' },
    { '<leader>di', function() require('dap').step_into() end, desc = 'Step into' },
    { '<leader>do', function() require('dap').step_out() end, desc = 'Step out' },
    { '<leader>dx', function() require('dap').terminate() end, desc = 'Stop and Exit' },
    { '<leader>dt', function() require("dapui").toggle() end, desc = 'Toggle UI' },
  },

  config = function()
    local dap = require 'dap'

    -----------------------------------------------------------------------------------------------
    -- Define signs for each icon explicitly
    vim.fn.sign_define('DapBreakpoint', {
      text = '●',
      texthl = 'red',
      linehl = '',
      numhl = '',
    })

    vim.fn.sign_define('DapBreakpointCondition', {
      text = ' ',
      texthl = 'DiagnosticInfo',
      linehl = nil,
      numhl = nil,
    })

    vim.fn.sign_define('DapBreakpointRejected', {
      text = ' ',
      texthl = 'DiagnosticInfo',
      linehl = nil,
      numhl = nil,
    })

    vim.fn.sign_define('DapLogPoint', {
      text = ' ',
      texthl = 'DiagnosticInfo',
      linehl = nil,
      numhl = nil,
    })

    -----------------------------------------------------------------------------------------------
    -- DAPUI
    local dapui = require 'dapui'
    dap.listeners.after.event_initialized['dapui_config'] = function()
      dapui.open { reset = true }
    end
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -----------------------------------------------------------------------------------------------
    -- Decides when and how to jump when stopping at a breakpoint
    -- The order matters!
    --
    -- (1) If the line with the breakpoint is visible, don't jump at all
    -- (2) If the buffer is opened in a tab, jump to it instead
    -- (3) Else, create a new tab with the buffer
    --
    -- This avoid unnecessary jumps
    require('dap').defaults.fallback.switchbuf = 'usevisible,usetab,newtab'

    -- TODO: add support for settings.json / tasks.json (with overseer?)

    -----------------------------------------------------------------------------------------------
    -- Javascript/Node Setup
    -- Debugger: "vscode-js-debug", installed with nix
    dap.adapters['pwa-node'] = {
      type = 'server',
      host = 'localhost',
      port = '${port}', --let both ports be the same for now...
      executable = {
        command = 'js-debug',
        args = { '${port}' },
      },
    }

    for _, language in ipairs { 'typescript', 'javascript' } do
      dap.configurations[language] = {
        {
          type = 'pwa-node',
          request = 'launch',
          name = 'Launch Current File (pwa-node)',
          cwd = '${workspaceFolder}', -- vim.fn.getcwd(),
          args = { '${file}' },
          sourceMaps = true,
          protocol = 'inspector',
        },
        {
          type = 'pwa-node',
          request = 'launch',
          name = 'Launch (Node)',
          program = '${file}',
          cwd = '${workspaceFolder}',
          runtimeExecutable = 'npx',
          runtimeArgs = { 'tsx' },
        },
        {
          -- use nvim-dap-vscode-js's pwa-node debug adapter
          type = 'pwa-node',
          -- attach to an already running node process with --inspect flag
          -- default port: 9222
          request = 'attach',
          -- allows us to pick the process using a picker
          processId = require('dap.utils').pick_process,
          -- name of the debug action you have to select for this config
          name = 'Attach to existing `node --inspect` process',
          -- for compiled languages like TypeScript or Svelte.js
          sourceMaps = true,
          -- resolve source maps in nested locations while ignoring node_modules
          resolveSourceMapLocations = {
            '${workspaceFolder}/**',
            '!**/node_modules/**',
          },
          -- path to src in vite based projects (and most other projects as well)
          cwd = '${workspaceFolder}/src',
          -- we don't want to debug code inside node_modules, so skip it!
          skipFiles = { '${workspaceFolder}/node_modules/**/*.js' },
        },
      }
    end
    -----------------------------------------------------------------------------------------------
    -- C-ish configurations.
    -- Debugger: "lldb-dap", installed with nix (lldb)
    dap.adapters.lldb = {
      name = 'lldb',
      type = 'executable',
      command = io.popen('which lldb-dap'):read '*l',
    }

    dap.configurations.c = {
      {
        name = 'Launch file',
        type = 'lldb',
        request = 'launch',
        program = function()
          return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
        end,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
        args = {},
      },
    }

    dap.configurations.cpp = dap.configurations.c
    dap.configurations.zig = dap.configurations.c
    dap.configurations.rust = dap.configurations.c
  end,
}
