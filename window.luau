--!strict
-- Window half: close commands. Tabs and splits are window state, so they live
-- here; a block (host half) has no cx.layout and cannot close anything.

local function keeper(cx: WindowCx): (number?, number?)
	local pane = cx.session:focused()
	return pane, (if pane then cx.session:tab_of(pane) else nil)
end

-- The current session's id, so close commands stay inside one session.
local function session_id(cx: WindowCx): number?
	for _, s in cx.session:sessions() do
		if s.current then
			return s.id
		end
	end
	return nil
end

local function report(cx: WindowCx, title: string, closed: number)
	cx:toast("info", title, string.format("closed %d block(s)", closed))
end

local function close_panes(cx: WindowCx, panes: { any }, skip: number, tab: number?): number
	local closed = 0
	for _, p in panes do
		if p.pane ~= skip and (tab == nil or p.tab == tab) then
			cx.layout:close(p.pane)
			closed += 1
		end
	end
	return closed
end

-- Split trees come back as nested tables, so walk them as `any`.
type Step = { axis: string, side: number }
type Leaf = { pane: number, path: { Step } }

local function walk(node: any, path: { Step }, out: { Leaf })
	if not node then
		return
	end
	if node.pane then
		table.insert(out, { pane = node.pane, path = path })
		return
	end
	if node.split == "right" or node.split == "down" then
		for side = 1, 2 do
			local next_path = table.clone(path)
			table.insert(next_path, { axis = node.split, side = side })
			walk(node[side], next_path, out)
		end
	end
end

-- Where `path` sits relative to `focus`, decided at the split where the two
-- first diverge: a "right" split puts side 1 to the left of side 2, a "down"
-- split puts side 1 above side 2.
local function side_of(path: { Step }, focus: { Step }): string?
	for i = 1, #path do
		local mine, theirs = path[i], focus[i]
		if not theirs or mine.side ~= theirs.side then
			if not theirs then
				return nil -- the focused block is inside this one
			end
			if mine.axis == "right" then
				return if mine.side == 1 then "left" else "right"
			end
			return if mine.side == 1 then "above" else "below"
		end
	end
	return nil
end

-- The blocks `want` of the focused one: same tab, split tree order.
local function side_of_focus(cx: WindowCx, want: string): { number }
	local focused, tab = keeper(cx)
	if not focused or not tab then
		return {}
	end
	local layout = cx.session:layout(tab)
	if not layout then
		return {}
	end
	local leaves: { Leaf } = {}
	walk(layout.root, {}, leaves)
	local focus = nil
	for _, leaf in leaves do
		if leaf.pane == focused then
			focus = leaf.path
		end
	end
	if not focus then
		return {} -- the focused block is a float, not in the tree
	end
	local panes = {}
	for _, leaf in leaves do
		if leaf.pane ~= focused and side_of(leaf.path, focus) == want then
			table.insert(panes, leaf.pane)
		end
	end
	return panes
end

-- `dir` is "left" or "right"; "above" and "below" work the same way.
local function close_side(cx: WindowCx, dir: string, title: string)
	local panes = side_of_focus(cx, dir)
	if #panes == 0 then
		cx:toast("info", title, "nothing on that side")
		return
	end
	for _, pane in panes do
		cx.layout:close(pane)
	end
	report(cx, title, #panes)
end

local function close_side_tabs(cx: WindowCx, dir: string, title: string)
	local _, keep = keeper(cx)
	if not keep then
		cx:toast("error", title, "no focused block")
		return
	end
	local session = session_id(cx)
	local tabs = cx.session:tabs()
	local here = nil
	for _, t in tabs do
		if t.id == keep then
			here = t.position
		end
	end
	if not here then
		cx:toast("error", title, "the focused block is not in a tab")
		return
	end
	local panes = cx.session:panes()
	local closed = 0
	for _, t in tabs do
		if t.session == session and t.id ~= keep and (t.position < here) == (dir == "left") then
			closed += close_panes(cx, panes, -1, t.id)
		end
	end
	report(cx, title, closed)
end

tern.command({
	id = "close-other-tabs",
	title = "Close other tabs",
	icon = "x",
	available = function(cx)
		return #cx.session:tabs() > 1
	end,
	run = function(cx)
		local _, keep = keeper(cx)
		if not keep then
			cx:toast("error", "Close other tabs", "no focused block")
			return
		end
		local session = session_id(cx)
		local panes = cx.session:panes()
		local closed = 0
		for _, t in cx.session:tabs() do
			if t.id ~= keep and t.session == session then
				closed += close_panes(cx, panes, -1, t.id)
			end
		end
		report(cx, "Close other tabs", closed)
	end,
})

tern.command({
	id = "close-left-tabs",
	title = "Close tabs left",
	icon = "x",
	available = function(cx)
		local _, keep = keeper(cx)
		for _, t in cx.session:tabs() do
			if t.id == keep then
				return t.position > 1
			end
		end
		return false
	end,
	run = function(cx)
		close_side_tabs(cx, "left", "Close tabs left")
	end,
})

tern.command({
	id = "close-right-tabs",
	title = "Close tabs right",
	icon = "x",
	available = function(cx)
		local _, keep = keeper(cx)
		local here, total = nil, 0
		for _, t in cx.session:tabs() do
			total += 1
			if t.id == keep then
				here = t.position
			end
		end
		return here ~= nil and here < total
	end,
	run = function(cx)
		close_side_tabs(cx, "right", "Close tabs right")
	end,
})

tern.command({
	id = "close-other-blocks",
	title = "Close other blocks",
	icon = "x",
	available = function(cx)
		local focused = cx.session:focused()
		local tab = if focused then cx.session:tab_of(focused) else nil
		if not tab then
			return false
		end
		local n = 0
		for _, p in cx.session:panes() do
			if p.tab == tab then
				n += 1
			end
		end
		return n > 1
	end,
	run = function(cx)
		local focused, keep = keeper(cx)
		if not focused or not keep then
			cx:toast("error", "Close other blocks", "no focused block")
			return
		end
		-- Same tab only; for the whole window pass tab = nil.
		report(cx, "Close other blocks", close_panes(cx, cx.session:panes(), focused, keep))
	end,
})

tern.command({
	id = "close-left-blocks",
	title = "Close blocks left",
	icon = "x",
	available = function(cx)
		return #side_of_focus(cx, "left") > 0
	end,
	run = function(cx)
		close_side(cx, "left", "Close blocks left")
	end,
})

tern.command({
	id = "close-right-blocks",
	title = "Close blocks right",
	icon = "x",
	available = function(cx)
		return #side_of_focus(cx, "right") > 0
	end,
	run = function(cx)
		close_side(cx, "right", "Close blocks right")
	end,
})
