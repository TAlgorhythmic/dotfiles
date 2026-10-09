return {
	"nvim-mini/mini.nvim",
	version = "*",
	config = function ()
		-- Comment module
		require("mini.comment").setup({
			options = {
				ignore_blank_line = true,
				pad_comment_starts = true,
			},
			mappings = {
				comment = "<leader>c"
			}
		})
	end
}
