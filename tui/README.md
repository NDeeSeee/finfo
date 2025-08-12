# finfotui (alpha)

A modern TUI for `finfo` built with Go + Bubble Tea + Bubbles + Lip Gloss.

- Two-phase design:
  - Phase 1: simple list + filter + selection (this repo), spawns `finfo --long` in a preview/detail page.
  - Phase 2: full multi-pane layout (files | preview | actions), async tasks (hashing, chmod, quarantine), tabs.

## Build

```bash
cd tui
go build -o finfotui ./...
```

Add to PATH or keep at `tui/finfotui` so `finfo tui` can launch it automatically.
