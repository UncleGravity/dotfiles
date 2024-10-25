return {
  {
    'supermaven-inc/supermaven-nvim',
    event = 'BufRead',
    config = function()
      require('supermaven-nvim').setup {}
    end,
  },
}
