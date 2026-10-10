return {
	"mfussenegger/nvim-jdtls",
	config = function()
		local dir = vim.fs.root(0, { 'gradlew', 'mvnw', 'pom.xml' })
		if dir == nil then
			return
		end
		local config = {
			cmd = {os.getenv("HOME") .. "/.local/share/nvim/mason/bin/jdtls"},
			root_dir = dir,
		}
		require("jdtls").start_or_attach(config)
	end,
}
