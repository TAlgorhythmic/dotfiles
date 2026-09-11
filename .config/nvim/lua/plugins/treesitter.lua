return {
	"nvim-treesitter/nvim-treesitter",
	-- Upstream moved default HEAD to `main`, which is an incompatible rewrite
	-- (no more nvim-treesitter.configs). Pin to master to keep this config.
	branch = "master",
	build = ":TSUpdate",
	config = function()
		-- Must run before any query is evaluated; see the file for why.
		require("ts-predicate-compat")

		-- Master's frozen lockfile pins tree-sitter-dart to 80e23c0 (2025-02),
		-- which predates Dart 3.10 dot shorthands (`.all(18)`, `.min`). Those
		-- parse as ERROR nodes and indent stops nesting inside the enclosing
		-- call. This newer grammar parses them; master's dart queries still
		-- load against it. After changing the revision, run :TSUpdate dart.
		require("nvim-treesitter.parsers").get_parser_configs().dart.install_info.revision =
			"be07cf7118d3dba06236a3f19541685a68209934"

		local config = require("nvim-treesitter.configs")
		config.setup({
			ensure_installed = { "c", "lua", "javascript", "html", "css", "angular", "astro", "bash", "cmake", "cpp", "csv", "cuda", "dart", "dockerfile", "groovy", "http", "java", "javascript", "json", "json5", "jsonnet", "kotlin", "llvm", "make", "markdown", "meson", "ninja", "powershell", "printf", "python", "ruby", "rust", "scala", "sql", "tsx", "typescript", "vue", "yaml", "zig" },
			highlight = { enable = true, additional_vim_regex_highlighting = false },
			-- c/cpp/java/typescript/tsx used to be disabled here because indent
			-- came out flat or mangled. That was the query-predicate crash fixed
			-- in ts-predicate-compat.lua, plus two missing query patterns now
			-- supplied by queries/{cpp,java}/indents.scm. All verified working.
			indent = { enable = true },
		})
	end,
}
