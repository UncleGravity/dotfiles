return {
  'mfussenegger/nvim-dap',
  lazy = true,
  dependencies = {
    { 'rcarriga/nvim-dap-ui', dependencies = { 'nvim-neotest/nvim-nio' } },
    'mxsdev/nvim-dap-vscode-js',
  },

  -- stylua: ignore
  keys = {
    -- normal mode is default
    { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = 'Toggle breakpoint' },
    { '<leader>dc', function() require('dap').continue() end, desc = 'Continue' },
    { "<leader>do", function() require('dap').step_over() end, desc = 'Step over' },
    { '<leader>di', function() require('dap').step_into() end, desc = 'Step into' },
    { '<leader>dx', function() require('dap').step_out() end, desc = 'Step out' },
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


    -- Javascript/Node Setup
    -- Debugger: "vscode-js-debug", installed with nix
    dap.adapters['pwa-node'] = {
      type = 'server',
      host = 'localhost',
      port = '${port}', --let both ports be the same for now...
      executable = {
        command = 'js-debug',
        args = { '${port}' },
        -- command = "js-debug-adapter",
        -- args = { "${port}" },
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
          name = 'Launch Current File (Typescript)',
          cwd = '${workspaceFolder}',
          runtimeArgs = { '--loader=ts-node/esm' },
          program = '${file}',
          runtimeExecutable = 'node',
          -- args = { '${file}' },
          sourceMaps = true,
          protocol = 'inspector',
          outFiles = { '${workspaceFolder}/**/**/*', '!**/node_modules/**' },
          skipFiles = { '<node_internals>/**', 'node_modules/**' },
          resolveSourceMapLocations = {
            '${workspaceFolder}/**',
            '!**/node_modules/**',
          },
        },
      }
    end
  end,
}
