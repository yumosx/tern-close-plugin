--!strict
-- Window half: eight close commands. Tabs and splits are window state, so they
-- live here; a block (host half) has no cx.layout and cannot close anything.
--
-- Every command is one `close_command` whose `targets` both decides whether
-- the row shows and names what to close, so the two can't drift apart.

-- The focused block and the tab holding it: what "others" is relative to.
local function keeper(cx: WindowCx): (number?, number?)
	local pane = cx.session:focused()
	return pane, (if pane then cx.session:tab_of(pane) else nil)
end

-- The current session's id, so tab commands stay inside one session.
local function session_id(cx: WindowCx): number?
	for _, s in cx.session:sessions() do
		if s.current then
			return s.id
		end
	end
	return nil
end

-- A session's tabs are one ordered list, however the tab bar is drawn, so
-- tabs only have "left" and "right": the ones before the focused block's and
-- the ones after it.
local function side_tabs(cx: WindowCx, dir: string): { number }
	local _, keep = keeper(cx)
	if not keep then
		return {}
	end
	local tabs = cx.session:tabs()
	local session, here = nil, nil
	for _, t in tabs do
		if t.id == keep then
			session, here = t.session, t.position
		end
	end
	if not here then
		return {}
	end
	-- Positions are per session, so only tabs of this session compare.
	local before = dir == "left"
	local ids = {}
	for _, t in tabs do
		if t.session == session and t.id ~= keep and (t.position < here) == before then
			table.insert(ids, t.id)
		end
	end
	return ids
end

-- Every tab of the focused block's session except its own.
local function other_tabs(cx: WindowCx): { number }
	local _, keep = keeper(cx)
	if not keep then
		return {}
	end
	local session = session_id(cx)
	local ids = {}
	for _, t in cx.session:tabs() do
		if t.session == session and t.id ~= keep then
			table.insert(ids, t.id)
		end
	end
	return ids
end

-- The panes of those tabs, in one pass over the window's panes.
local function panes_of(cx: WindowCx, tabs: { number }): { number }
	local wanted = {}
	for _, id in tabs do
		wanted[id] = true
	end
	local ids = {}
	for _, p in cx.session:panes() do
		if p.tab ~= nil and wanted[p.tab] then
			table.insert(ids, p.pane)
		end
	end
	return ids
end

-- Split trees come back as nested tables, so walk them as `any`.
type Step = { axis: string, side: number }
type Leaf = { pane: number, path: { Step } }

-- One clone per leaf, not one per level: the stack is reused down the tree.
local function walk(node: any, stack: { Step }, out: { Leaf })
	if not node then
		return
	end
	if node.pane then
		table.insert(out, { pane = node.pane, path = table.clone(stack) })
		return
	end
	if node.split == "right" or node.split == "down" then
		table.insert(stack, { axis = node.split, side = 1 })
		walk(node[1], stack, out)
		stack[#stack] = { axis = node.split, side = 2 }
		walk(node[2], stack, out)
		table.remove(stack)
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

-- The blocks `dir` of the focused one: its tab's split tree, not list order.
local function side_blocks(cx: WindowCx, dir: string): { number }
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
	local ids = {}
	for _, leaf in leaves do
		if leaf.pane ~= focused and side_of(leaf.path, focus) == dir then
			table.insert(ids, leaf.pane)
		end
	end
	return ids
end

-- The other blocks of the focused one's tab. This matches on the pane's tab,
-- so a float over that tab goes with it while side_blocks leaves it alone.
local function other_blocks(cx: WindowCx): { number }
	local focused, tab = keeper(cx)
	if not focused or not tab then
		return {}
	end
	local ids = {}
	for _, p in cx.session:panes() do
		if p.tab == tab and p.pane ~= focused then
			table.insert(ids, p.pane)
		end
	end
	return ids
end

local function close(cx: WindowCx, title: string, panes: { number })
	if #panes == 0 then
		cx:toast("info", title, "nothing to close")
		return
	end
	for _, pane in panes do
		cx.layout:close(pane)
	end
	cx:toast("info", title, string.format("closed %d block(s)", #panes))
end

-- `targets` runs for the palette's availability check and again for the run,
-- so it stays a couple of table reads plus, for blocks, one tree walk.
local function close_command(id: string, title: string, targets: (WindowCx) -> { number })
	return {
		id = id,
		title = title,
		icon = "x",
		available = function(cx: WindowCx): boolean
			return #targets(cx) > 0
		end,
		run = function(cx: WindowCx)
			close(cx, title, targets(cx))
		end,
	}
end

tern.command(close_command("close-other-tabs", "Close other tabs", function(cx)
	return panes_of(cx, other_tabs(cx))
end))

tern.command(close_command("close-left-tabs", "Close tabs left", function(cx)
	return panes_of(cx, side_tabs(cx, "left"))
end))

tern.command(close_command("close-right-tabs", "Close tabs right", function(cx)
	return panes_of(cx, side_tabs(cx, "right"))
end))

tern.command(close_command("close-other-blocks", "Close other blocks", function(cx)
	return other_blocks(cx)
end))

tern.command(close_command("close-left-blocks", "Close blocks left", function(cx)
	return side_blocks(cx, "left")
end))

tern.command(close_command("close-right-blocks", "Close blocks right", function(cx)
	return side_blocks(cx, "right")
end))

tern.command(close_command("close-above-blocks", "Close blocks above", function(cx)
	return side_blocks(cx, "above")
end))

tern.command(close_command("close-below-blocks", "Close blocks below", function(cx)
	return side_blocks(cx, "below")
end))
