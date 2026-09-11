vim.cmd("set allowrevins")
vim.cmd("set cursorline")
vim.cmd("set autowrite")
vim.cmd("set autowriteall")
vim.cmd("set bex=.bak")
-- No quotes around any `:set` value: `"` starts a comment on an Ex command
-- line, so `set complete=".,w,b"` silently sets the option to *empty* rather
-- than to the list. That quietly disabled ins-completion and re-enabled every
-- bell for a while.
vim.cmd("set belloff=error,esc,hangul,lang")
vim.cmd("set breakindent")
vim.cmd("set bufhidden=hide")
vim.cmd("set casemap=internal")
vim.cmd("set cdpath=.,,~/projects")
-- No global 'cindent': it's a C/Java indenter and becomes the fallback for any
-- filetype without an indentexpr, which mangles them (Dart especially).
-- Nvim's default 'autoindent' is on already; real indenters come from
-- treesitter/ftplugin per filetype.
vim.cmd("set complete=.,w,b,u,U,i,d,t")
vim.cmd("set confirm")
vim.cmd("set noexpandtab")
vim.cmd("set tabstop=4")
vim.cmd("set softtabstop=4")
vim.cmd("set shiftwidth=4")
vim.cmd("set number")

-- Set leaders before loading lazy.nvim so plugin mappings are correct.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local colorspath = vim.fn.stdpath("data") .. "/colors"

-- Bootstrap lazy.nvim
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end

vim.opt.rtp:prepend(lazypath)
vim.opt.rtp:prepend(colorspath)
-- require("algorhythmics")
require("lazy").setup({
	spec = {
		{ import = "plugins"},
	},
	checker = { enabled = true }
})

vim.diagnostic.config({
	virtual_text = true,
})

--[[require("modus-themes").setup({
	variants = {
		modus_operandi = "default",
		modus_vivendi = "default",
	},
	transparent = false,
	dim_inactive = false,
	hide_inactive_statusline = false,
	styles = {
		comments = { italic = false },
		functions = { fg = "#CFFFF7", italic = false },
		keywords = { bold = true, italic = false },
	},
	on_colors = function() end,
	on_highlights = function() end,
})]]

vim.cmd("colorscheme cyberdream")

vim.api.nvim_set_hl(0, "Number", { fg = "#33CCFF", bold = true })
vim.api.nvim_set_hl(0, "Constant", { fg = "#77A7FF" })
vim.api.nvim_set_hl(0, "Keyword", { fg = "#D06FFF", bold = true })
vim.api.nvim_set_hl(0, "Operator", { fg = "#ffffff" })
vim.api.nvim_set_hl(0, "String", { fg = "#e1d900" })
vim.api.nvim_set_hl(0, "@variable", { fg = "#C7FAFF" })
vim.api.nvim_set_hl(0, "Identifier", { fg = "#B3CAFF" })
vim.api.nvim_set_hl(0, "Delimiter", { fg = "#9F9F9F" })
vim.api.nvim_set_hl(0, "Function", { fg = "#D0FFE1" })
vim.api.nvim_set_hl(0, "@lsp.type.selfTypeKeyword.rust", { fg = "#bd5eff" })
vim.api.nvim_set_hl(0, "@lsp.type.typeAlias.rust", { fg = "#00F7FF" })
vim.api.nvim_set_hl(0, "Type", { fg = "#00E6B1" })
vim.api.nvim_set_hl(0, "@type.builtin", { fg = "#00E6B1" })

vim.cmd("hi link @keyword.function Keyword")
vim.cmd("hi link @type.builtin Type")
vim.cmd("hi link @lsp.type.interface.rust Constant")
vim.cmd("hi link htmlTagName Type");
vim.cmd("hi link typescriptVariableDeclaration Identifier")
vim.cmd("hi link typescriptIdentifierName Constant")
vim.cmd("hi link typescriptVariable Keyword")
vim.cmd("hi link typescriptArrayMethod Function")
vim.cmd("hi link @lsp.type.variable Identifier")
vim.cmd("hi link tsxAttrib Variable")
vim.cmd("hi link typescriptDefault Keyword")
vim.cmd("hi link @lsp.type.modifier.java Keyword")
vim.cmd("hi link @keyword.type.java Keyword")
vim.cmd("hi link @type.builtin.java @type.builtin")

local map = vim.api.nvim_set_keymap
local optss = { noremap = true, silent = true }

-- time-tracker is configured in lua/plugins/time-tracker.lua. Calling
-- setup() here as well forced the plugin to load at startup, defeating its
-- `event = "VeryLazy"`, and applied a second, different set of options.

-- Mappings
map('n', '<A-Left>', '<Cmd>BufferPrevious<CR>', optss)
map('n', '<A-Right>', '<Cmd>BufferNext<CR>', optss)
map('n', '<C-D>', '<Cmd>NvimTreeToggle<CR>', optss)

-- Flutter
map('n', '<leader><C-r>', '<Cmd>FlutterRun<CR>', optss)
map('n', '<leader><C-h>', '<Cmd>FlutterDebug<CR>', optss)
map('n', '<leader><C-f>', '<Cmd>FlutterEmulators<CR>', optss)
map('n', '<leader><C-n>', '<Cmd>FlutterReload<CR>', optss)

map('n', '<leader><Left>', '<Cmd>BufferMovePrevious<CR>', optss)
map('n', '<leader><Right>', '<Cmd>BufferMoveNext<CR>', optss)
map('n', '<A-p>', '<Cmd>BufferPin<CR>', optss)
map("n", "<C-c>", "<Cmd>BufferClose<CR>", optss)
map('n', '<C-z>', 'u', optss)
map('n', '<C-y>', '<C-r>', optss)
map('i', '<C-z>', '<C-o>u', optss)
map('i', '<C-y>', '<C-o><C-r>', optss)
map('t', "<C-Up>", [[<C-\><C-n><C-w>k]], optss)
map('t', '<C-Left>', [[<C-\><C-n><C-w>h]], optss)
map('t', '<C-Right>', [[<C-\><C-n><C-w>l]], optss)
map('n', "<C-Up>", [[<C-\><C-n><C-w>k]], optss)
map('n', '<C-Left>', [[<C-\><C-n><C-w>h]], optss)
map('n', '<C-Right>', [[<C-\><C-n><C-w>l]], optss)
map('n', '<C-Down>', [[<C-\><C-n><C-w>j]], optss)
map("n", "<leader>1", "<cmd>lua vim.lsp.buf.definition()<CR>", optss)
map("n", "<leader>2", '<cmd>lua vim.lsp.buf.code_action()<CR>', optss)
map("n", "<leader>3", "<cmd>lua vim.lsp.buf.hover()<CR>", optss)
map("n", "<leader>4", "<cmd>lua vim.lsp.buf.references()<CR>", optss)
map("n", "<leader>5", "<cmd>Telescope lsp_references<CR>", optss)
map("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", optss)
map("n", "<leader>lf", "<cmd>lua vim.lsp.buf.format{ async = true }<cr>", optss)
map("n", "<leader>li", "<cmd>LspInfo<cr>", optss)
map("n", "<leader>lI", "<cmd>LspInstallInfo<cr>", optss)
map("n", "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>", optss)
-- goto_next/goto_prev are deprecated since 0.11; jump() replaces both.
map("n", "<leader>lj", "<cmd>lua vim.diagnostic.jump({ count = 1, float = true })<cr>", optss)
map("n", "<leader>lk", "<cmd>lua vim.diagnostic.jump({ count = -1, float = true })<cr>", optss)
map("n", "<leader>r", "<cmd>lua vim.lsp.buf.rename()<cr>", optss)
map("n", "<leader>ls", "<cmd>lua vim.lsp.buf.signature_help()<CR>", optss)
map("n", "<leader>lq", "<cmd>lua vim.diagnostic.setloclist()<CR>", optss)
map("n", "<A-o>", "<Cmd>lua require('jdtls').organize_imports()<CR>", optss)
map("i", "<A-o>", "<Cmd>lua require('jdtls').organize_imports()<CR>", optss)
map('i', '<Esc>', [[pumvisible() ? "\<C-e>" : "\<Esc>"]], { expr = true, silent = true })
map(
	"i",
	"<CR>",
	[[pumvisible() ? (complete_info().selected == -1 ? "\<C-e><CR>" : "\<C-y>") : "\<CR>"]],
	{ expr = true, silent = true }
)
map('i', '<Tab>', [[pumvisible() ? "\<C-n>" : "\<Tab>"]], { expr = true, silent = true })
map('i', '<S-Tab>', [[pumvisible() ? "\<C-p>" : "\<BS>"]], { expr = true, silent = true })
-- NOTE: do not add a second <CR> map here. There was one using single quotes
-- ('<Down><CR>'), which both shadowed the mapping above and, because
-- nvim_set_keymap leaves replace_keycodes off, inserted the literal text
-- "<Down><CR>" whenever the popup menu was open.
