# tern-close-plugin

Six Tern commands that close tabs and split blocks around the block you have focused.

Window half only. Tabs and splits are window state, and the host half of a plugin has no layout access, so there is nothing to run in the daemon.

## Commands

| Action | Palette row | Closes |
| --- | --- | --- |
| `plugin.close-tab.close-other-tabs` | Close other tabs | every tab of the current session except the focused block's |
| `plugin.close-tab.close-left-tabs` | Close tabs left | the tabs before it |
| `plugin.close-tab.close-right-tabs` | Close tabs right | the tabs after it |
| `plugin.close-tab.close-other-blocks` | Close other blocks | the other blocks in the focused block's tab |
| `plugin.close-tab.close-left-blocks` | Close blocks left | the blocks left of it in the split tree |
| `plugin.close-tab.close-right-blocks` | Close blocks right | the blocks right of it |

Every row is hidden while it would close nothing, so the palette only offers a command that does something.

## Install

```sh
tern plugin link ~/src/tern-close-plugin
tern plugin list
```

```text
close-tab 0.1.0 Close Tab — 0 blocks, 0 lenses, window  ready
```

A running daemon reloads the plugin on `link`, and again about 300 ms after you save a file in the folder. `tern plugin reload` forces it and exits 1 when a plugin failed or a folder has problems.

## Key bindings

No default chords. Bind the actions wherever you keep your keys, for example in another window half:

```lua
tern.bind("cmd+alt+w", "plugin.close-tab.close-other-tabs")
tern.bind("cmd+alt+left", "plugin.close-tab.close-left-blocks")
tern.bind("cmd+alt+right", "plugin.close-tab.close-right-blocks")
```

## Behavior

**It is destructive.** Every command closes panes with `cx.layout:close`, the raw session close that plugins get. Programs in those panes end immediately, there is no confirmation, and the palette does not tint these rows the way it tints the built-in `close_pane`.

**Tab commands stay inside one session.** `close_tab` is per session, so `session_id` in `window.luau` reads the current session and skips the rest. Drop that check to sweep every session.

**Block commands stay in the focused tab.** `close-other-blocks` passes the tab id to `close_panes`; passing `nil` closes every other block in the window instead.

**Left and right come from the split tree, not from a list.** `side_of_focus` walks `cx.session:layout(tab).root` and tags each leaf with the split decisions above it. Two leaves are compared at the first split where their paths diverge: under a `"right"` split, side 1 is left of side 2; under a `"down"` split, side 1 is above side 2. So a horizontal row of splits closes the way you expect, a vertical stack is not "left" and stays open. Vertical commands are one registration away:

```lua
close_side(cx, "above", "Close blocks above")
close_side(cx, "below", "Close blocks below")
```

**Floating blocks are not in the split tree.** The side commands leave them alone. `close-other-blocks` matches on the pane's tab id, so it closes floats along with the tab.

## Development

```sh
tern plugin types .   # writes tern.d.luau: WindowCx, TabInfo, PaneInfo and the rest
luau-lsp analyze --platform=standard --definitions=@tern=tern.d.luau window.luau
```

`tern.d.luau` is generated. Regenerate it after upgrading Tern.

Budgets: an `available` check has 4 ms and runs every time the palette opens, `run` has 50 ms. A handler that raises toasts `Plugin Close Tab: command <id> failed`; the full traceback goes to the log under the `tern::plugin` target, which the default filter drops. Start Tern with `STENCIL_LOG=warn,stencil=info,tern::plugin=debug` to see it.

## What a plugin cannot do here

The block's ⋯ menu offers no insertion point. Its rows are built-in commands (`paste`, `split_right`, `split_down`, `pip`, `zoom`, `move_pane_to_tab`, `find`, `close_pane`), and the window-side surface a plugin can register is `tern.command`, `tern.bind`, `tern.override`, `tern.route.open`, `tern.route.link`, `tern.chrome.*`, `tern.css` and `tern.on`. Nothing there adds a menu row.

What is reachable instead:

- `tern.override("close_pane", fn)` changes what the existing Close block row does, since an override runs however the command was started. It cannot add a row, and it changes the behavior for everyone.
- A block type with `files` globs gets an "Open with \<title\>" item in file-block and Files pane menus, but choosing it opens a block; it cannot run a close.
- `tern.chrome.status` draws clickable text in the status line, where `command` takes any action name. The formatter receives only `{pane, cwd, program, title, busy}`, so it cannot check the tab count and such a chip is always visible.

So these commands live in the palette and in key bindings.

## Files

- `plugin.toml` — manifest, window entry only
- `window.luau` — the six commands and their shared helpers
- `tern.d.luau` — generated API type definitions
