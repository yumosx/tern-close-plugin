# tern-close-plugin

Eight Tern commands that close tabs and split blocks around the block you have focused.

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
