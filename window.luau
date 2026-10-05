--!strict
-- Window half: close commands. Tabs and splits are window state, so they live
-- here; a block (host half) has no cx.layout and cannot close anything.

-- The focused block and the tab holding it: what "others" is relative to.
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

tern.command({
	id = "close-other-tabs",
	title = "Close other tabs",
	icon = "x",
	available = function(cx)
		return #cx.session:tabs() > 1
	end,
	run = function(cx)
		local focused, keep = keeper(cx)
		if not focused or not keep then
			cx:toast("error", "Close other tabs", "no focused block")
			return
		end
		local session = session_id(cx)
		local panes = cx.session:panes()
		local closed = 0
		for _, t in cx.session:tabs() do
			if t.id ~= keep and t.session == session then
				for _, p in panes do
					if p.tab == t.id then
						cx.layout:close(p.pane)
						closed += 1
					end
				end
			end
		end
		report(cx, "Close other tabs", closed)
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
		-- Same tab only; for the whole window drop `p.tab == keep`, and to
		-- leave floating blocks alone add `and not p.floating`.
		local closed = 0
		for _, p in cx.session:panes() do
			if p.tab == keep and p.pane ~= focused then
				cx.layout:close(p.pane)
				closed += 1
			end
		end
		report(cx, "Close other blocks", closed)
	end,
})
