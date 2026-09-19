return {
	"nvim-treesitter/nvim-treesitter",
	-- `main` is a full, incompatible rewrite. The plugin is now *only* a
	-- parser/query installer: no `nvim-treesitter.configs`, no modules. The
	-- features it used to switch on are Neovim's, and we opt in below.
	-- The old `master` pin is frozen against Nvim 0.11 and was steadily
	-- breaking on 0.12 (see git history for the predicate shim this replaces).
	branch = "main",
	lazy = false, -- main explicitly does not support lazy-loading
	build = ":TSUpdate",
	config = function()
		local ts = require("nvim-treesitter")

		-- Parsers and queries install into `stdpath('data')/site`, already on
		-- the default runtimepath, so no setup() call is needed to find them.
		-- install() is async and a no-op for whatever is already present.
		--
		-- master resolved parser dependencies implicitly; main does not, so
		-- markdown_inline has to be listed alongside markdown.
		ts.install({
			"angular", "astro", "bash", "c", "cmake", "cpp", "css", "csv",
			"cuda", "dart", "dockerfile", "groovy", "html", "http", "java",
			"javascript", "json", "json5", "jsonnet", "kotlin", "llvm", "lua",
			"make", "markdown", "markdown_inline", "meson", "ninja",
			"powershell", "printf", "python", "ruby", "rust", "scala", "sql",
			"tsx", "typescript", "vue", "yaml", "zig",
		})

		-- `highlight`/`indent` used to be flags in configs.setup. On main every
		-- buffer opts in itself.
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("user_treesitter", { clear = true }),
			callback = function(args)
				local lang = vim.treesitter.language.get_lang(args.match)
				if not lang then
					return
				end
				-- start() asserts on a missing parser, which would throw for
				-- every filetype outside the list above.
				if not pcall(vim.treesitter.start, args.buf, lang) then
					return
				end
				-- The highlighter clears `syntax` itself, so this is already
				-- master's `additional_vim_regex_highlighting = false`.

				-- Only claim indentexpr where an indents query exists: without
				-- one nvim-treesitter's indent returns 0 for every line and
				-- flattens the file. This is what queries/{cpp,java}/indents.scm
				-- extend.
				if vim.treesitter.query.get(lang, "indents") then
					vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end
			end,
		})
	end,
}
