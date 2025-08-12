# finfotui (alpha)

A modern TUI for `finfo` built with Go + Bubble Tea + Bubbles + Lip Gloss.

## Features

- Split layout: filterable file list (left) and JSON-driven preview (right)
- Keybindings:
  - Navigation: `↑/k`, `↓/j`, `/` filter, `R` refresh, `q` quit
  - View: `l` toggle long/brief (affects preview)
  - Actions: `a` action palette overlay; `c` copy; `o` open; `E` reveal (macOS);
    `r` clear quarantine (macOS, with confirmation); `m` chmod prompt
  - Selection: `space` toggle select; `A` select all; `V` clear selection
  - Help: `?` show keymap/help overlay
- Async preview loading with timeout to keep UI responsive
- Status bar with live async job spinner and counts (running/done/failed)
- Theming via `FINFOTUI_THEME` env (`default`, `mono`, `nord`, `dracula`)

## Build

```bash
cd tui
go build -o finfotui ./...
```

Add to PATH or keep at `tui/finfotui` so `finfo tui` can launch it automatically.

## Run

```bash
finfo tui PATH...
```

If `finfotui` is not on PATH, `finfo tui` will attempt to launch `tui/finfotui` if present, otherwise it falls back to the shell TUI.

## Theming

Set `FINFOTUI_THEME` to switch styles:

```bash
export FINFOTUI_THEME=nord   # default|mono|nord|dracula
```
