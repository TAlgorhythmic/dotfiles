return {
   'nvim-telescope/telescope.nvim',
   tag = '0.1.8',
   dependencies = { 'nvim-lua/plenary.nvim' },
   config = function()
      local builtin = require("telescope.builtin")

      local show_hidden_args = { "--hidden", "--glob", "!.git/" }

      vim.keymap.set('n', '<leader>p', function()
         builtin.find_files({ find_command = { "rg", "--files", unpack(show_hidden_args) } })
      end, {})
      vim.keymap.set('n', '<leader>f', function()
         builtin.live_grep({ additional_args = show_hidden_args })
      end, {})
   end,
}

