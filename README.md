# tern-close-plugin

Eight Tern commands that close tabs and split blocks around the block you have focused.

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
| `plugin.close-tab.close-above-blocks` | Close blocks above | the blocks above it |
| `plugin.close-tab.close-below-blocks` | Close blocks below | the blocks below it |

Tabs are one ordered list, however the tab bar is drawn (along the top or down the left edge), so tabs only get left and right. Blocks sit in a two-dimensional split tree, so they get all four directions.

Every row is hidden while it would close nothing, so the palette only offers a command that does something.

## Install

```sh
tern plugin install github.com/yumosx/tern-close-plugin
tern plugin list
```

```text
close-tab 0.1.0 Close Tab — 0 blocks, 0 lenses, window  ready
```

`install` clones the repo into Tern's plugins directory, and a running daemon reloads it there. `tern plugin remove close-tab` deletes the copy. `--force` replaces an installed copy after an update, and never a linked one.

Working from a checkout instead: `tern plugin link ~/src/tern-close-plugin` uses the plugin where it is, and the daemon reloads again about 300 ms after you save a file in the folder. `tern plugin unlink close-tab` drops the link.

`tern plugin reload` forces a reload and exits 1 when a plugin failed or the folder has problems.
*** END

## Key bindings

No default chords. Bind the actions wherever you keep your keys, for example in another window half:

```lua
tern.bind("cmd+alt+w", "plugin.close-tab.close-other-tabs")
tern.bind("cmd+alt+left", "plugin.close-tab.close-left-blocks")
tern.bind("cmd+alt+right", "plugin.close-tab.close-right-blocks")
```

## Behavior

**It is destructive.** Every command closes panes with `cx.layout:close`, the raw session close that plugins get. Programs in those panes end immediately, there is no confirmation, and the palette does not tint these rows the way it tints the built-in `close_pane`.

**One `targets` per command.** Each registration is a `close_command` that takes a function returning the pane ids to close. That same function answers the palette's availability check, so a row can only appear when its own run would find something, and the two cannot drift apart.

**Tab commands stay inside one session.** `close_tab` is per session, so `session_id` in `window.luau` reads the current session and every comparison filters on `t.session`. Drop those checks to sweep every session.

**Block commands stay in the focused tab.** `other_blocks` matches on the pane's tab id; widen it to every tab and `close-other-blocks` closes around the focused block in the whole window.

**Block directions come from the split tree, not from a list.** `side_blocks` walks `cx.session:layout(tab).root` and tags each leaf with the split decisions above it. Two leaves are compared at the first split where their paths diverge: under a `"right"` split, side 1 is left of side 2; under a `"down"` split, side 1 is above side 2. So a horizontal row closes left and right the way you expect, a vertical stack closes above and below, and a vertical stack is never swept up as "left". The walk clones one path per leaf, not one per level.

**Positions are per session.** `TabInfo.position` counts tabs within its own session and `cx.session:tabs()` returns tabs of every session, so every comparison here filters on `t.session` first, including the `available` checks.

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
- `window.luau` — the eight commands and their shared helpers
- `tern.d.luau` — generated API type definitions
