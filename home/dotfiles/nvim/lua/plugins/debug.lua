return {
  'mfussenegger/nvim-dap',
  lazy = true,
  dependencies = {
    { 'rcarriga/nvim-dap-ui', dependencies = { 'nvim-neotest/nvim-nio' } },
    {
      'mfussenegger/nvim-dap-python',
      config = function()
        require('dap-python').setup()
      end,
    },
    -- Virtual text.
    {
      'theHamsta/nvim-dap-virtual-text',
      opts = { virt_text_pos = 'eol' },
    },
  },

  -- stylua: ignore
  keys = {
    -- normal mode is default
    { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = 'Toggle breakpoint' },
    { '<leader>dc', function() require('dap').continue() end, desc = 'Continue' },
    { "<leader>dn", function() require('dap').step_over() end, desc = 'Step over (next)' },
    { '<leader>di', function() require('dap').step_into() end, desc = 'Step into' },
    { '<leader>do', function() require('dap').step_out() end, desc = 'Step out' },
    { '<leader>dx', function() require('dap').stop() end, desc = 'Stop and Exit' },
    { '<leader>dt', function() require("dapui").toggle() end, desc = 'Toggle UI' },
  },

  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    dapui.setup()

    dap.listeners.after.event_initialized['dapui_config'] = function()
      dapui.open { reset = true }
    end
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close


    -- TODO: add Clang debugging
    -- https://discourse.nixos.org/t/how-to-get-codelldb-on-nixos/30401

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
  end,
}
