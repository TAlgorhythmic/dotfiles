-- Compatibility shim: nvim-treesitter `master` vs Neovim 0.11+ predicate API.
--
-- nvim-treesitter master registers its custom predicates with
-- `{ force = true, all = false }`, which used to make Neovim hand the handler a
-- single TSNode per capture. Neovim 0.11 deprecated `all = false` and 0.12
-- dropped it: handlers now always receive `match[capture_id]` as a *list* of
-- nodes. Master is frozen (last commit 2026-03-23), so it will never be fixed
-- upstream, and every affected handler dies with
--   "attempt to call method 'type' (a nil value)".
--
-- An error thrown inside `Query:iter_captures()` aborts the whole capture loop,
-- so nvim-treesitter's indent module silently ends up with a partial (often
-- empty) capture map and returns 0 for every line -- i.e. no indentation at all.
-- This is what made treesitter indent look "broken" for C and TypeScript.
--
-- Re-register the affected predicates with the current signature, unwrapping
-- the node list the way the old `all = false` path did (last node wins).

require "nvim-treesitter.query_predicates" -- ensure the originals exist first

local query = require "vim.treesitter.query"
local opts = { force = true }

---Take the single node the old `all = false` API would have passed.
---@param match table<integer, TSNode[]>
---@param capture_id integer
---@return TSNode|nil
local function one(match, capture_id)
	local nodes = match[capture_id]
	if type(nodes) ~= "table" then
		return nodes -- already a bare node (older Neovim)
	end
	return nodes[#nodes]
end

query.add_predicate("kind-eq?", function(match, _pattern, _bufnr, pred)
	local node = one(match, pred[2])
	if not node then
		return true
	end
	return vim.tbl_contains({ unpack(pred, 3) }, node:type())
end, opts)

query.add_predicate("nth?", function(match, _pattern, _bufnr, pred)
	local node = one(match, pred[2])
	local n = tonumber(pred[3])
	local parent = node and node:parent()
	if parent and n and parent:named_child_count() > n then
		return parent:named_child(n) == node
	end
	return false
end, opts)

query.add_predicate("is?", function(match, _pattern, bufnr, pred)
	local node = one(match, pred[2])
	if not node then
		return true
	end
	local locals = require "nvim-treesitter.locals"
	local _, _, kind = locals.find_definition(node, bufnr)
	return vim.tbl_contains({ unpack(pred, 3) }, kind)
end, opts)
