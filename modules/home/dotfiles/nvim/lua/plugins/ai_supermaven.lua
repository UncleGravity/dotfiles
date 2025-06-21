return {
  {
    'supermaven-inc/supermaven-nvim',
    enabled = false,
    event = 'BufRead',
    config = function()
      require('supermaven-nvim').setup {}
    end,
  },
}
