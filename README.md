# finfo

[![CI](https://github.com/NDeeSeee/finfo/actions/workflows/ci.yml/badge.svg)](https://github.com/NDeeSeee/finfo/actions/workflows/ci.yml)

Fast, colorful file/dir inspector for zsh (macOS-friendly). Pretty human output by default; stable porcelain/JSON for tooling; modular helpers in `lib/`.

## Features

- Pretty sections: Essentials, Timeline, Paths, Security & Provenance, Actions, Tips
- Multi-target SUMMARY with sorted type breakdown, total bytes, quarantine count, hardlink presence, Top-N largest files
- Quick stats by type: PDF pages (mdls), Markdown headings, CSV delimiter/columns, image WxH (sips), media duration (mdls)
- Security: gatekeeper/codesign/notarization/quarantine/where_froms with a simple verdict
- Subcommands: `diff`, `chmod` (interactive), `watch`
- Outputs: `--porcelain`, `--json` and `--html` report

## Directory layout

- `finfo.zsh`: orchestrator (flags, core facts, delegates to modules)
- `lib/` helpers:
  - `_colors.zsh`, `_icons.zsh`, `_format.zsh`, `_size.zsh`, `_sections.zsh`, `_actions.zsh`
  - `_security.zsh`, `_filetype.zsh`, `_summary.zsh`, `_checksum.zsh`, `_monitor.zsh`, `_html.zsh`, `_git.zsh`, `_config.zsh`
  - `cmd/`: subcommands (`cmd_diff.zsh`, `cmd_watch.zsh`, `cmd_chmod.zsh`, `cmd_duplicates.zsh`)

Planned reorg:

- subcommands now load from `lib/cmd/` if present, falling back to legacy `lib/` paths
- consider adding `docs/` and `tests/` directories

## CLI

```bash
finfo [--brief|--long|--porcelain|--json|--html] [--width N] [--hash sha256|blake3] \
      [--unit bytes|iec|si] [--icons|--no-icons] [--git|--no-git] [--monitor] [--duplicates] \
      [--keys|--no-keys] [--keys-timeout N] [--copy-path|-C] [--copy-rel] [--copy-dir] \
      [--copy-hash ALGO] [--open|-O] [--open-with APP] [--reveal|-E] [--edit APP|-e APP] \
      [--chmod OCTAL] [--clear-quarantine|-Q] [--risk|-S] [--qr-hash ALGO] PATH...

finfo diff A B             # metadata diff (porcelain-based)
finfo chmod PATH           # interactive chmod helper (arrows/space/s/q)
finfo watch PATH [secs]    # live sample size/mtime/quarantine changes
finfo html --dashboard DIR # export dist/index.html dashboard for quick browsing
finfo tui [PATH…]          # interactive TUI (Go app if installed; shell fallback)
```

### Keys panel

- `--keys` shows a KEYS panel at the bottom (TTY-only) and accepts a single keypress to run a shortcut.
- `--long` auto-enables the KEYS panel unless `--no-keys` is passed.
- `--keys-timeout N` controls how long to wait for a keypress (default 5s).
- Shortcuts: `o` open in default app, `r` reveal in Finder, `p` copy absolute path, `q` quit.

## JSON schema (selected)

```json
{
  "name": "",
  "path": {"abs": "", "rel": ""},
  "is_dir": false,
  "type": {"description": "", "is_text": "text|binary|n/a", "charset": ""},
  "size": {"bytes": 0, "human": ""},
  "lines": 0|null,
  "perms": {"symbolic": "", "octal": "", "explain": "read-write, executable"},
  "dates": {"created": "", "modified": ""},
  "git": {"present": true, "branch": "", "status": "clean|modified|..."},
  "security": {
    "gatekeeper": "pass|fail|unknown",
    "codesign": {"signed": 0|1, "status": "valid|invalid|unknown", "team": ""},
    "notarization": "ok|missing|unknown",
    "quarantine": "yes|no",
    "where_froms": "",
    "verdict": "safe|caution|unsafe|unknown"
  },
  "links": {"hardlinks": 1|null},
  "symlink": {"is_symlink": false, "target": "", "target_exists": 0},
  "dir": {"num_dirs": 0, "num_files": 0, "size_human": ""},
  "filetype": {"pages": null, "headings": null, "columns": null, "delimiter": "", "image_dims": ""},
  "about": "",
  "quality": ["shellcheck '...'"]
}
```

## Porcelain keys (selected)

```text
name, type, size_bytes, size_human, lines, mime, uttype, owner_group, perms_sym, perms_oct,
created, modified, accessed, rel, abs, symlink, hardlinks, gatekeeper, codesign_status,
codesign_team, notarization, verdict, where_froms, quarantine, sha256|blake3,
pages, headings, columns, delimiter, image_dims, about
```

## Notes

- Use `--unit bytes|iec|si` to control human size units in pretty output
- Set `FINFO_TOPN` to adjust Top-N largest files in SUMMARY (default 5)
- macOS integrations (mdls, sips, spctl, codesign, stapler, xattr) are best-effort and guarded

### Platform notes

- macOS: rich Security/UTType fields; KEYS and open/reveal shortcuts use `open`, clipboard uses `pbcopy`.
- Linux: Security/UTType shown as `unknown`; open uses `xdg-open`; clipboard uses `wl-copy`/`xclip` when available.
- Porcelain/JSON schemas are stable; pretty output is human-oriented.

## Dependencies

See `dependencies/README.md` for essential and optional tools (install commands for macOS and Linux), fonts, and environment variables. finfo degrades gracefully when extras are missing.

## Dashboard export

Quickly produce a single-file HTML dashboard:

```bash
./finfo.zsh html --dashboard .
open dist/index.html # macOS
```

## Export reports (JSON / YAML)

- Save JSON directly:

```bash
./finfo.zsh --json PATH > report.json
```

- Save YAML (requires `yq`):

```bash
./finfo.zsh --json PATH | yq -P > report.yaml
```

Planned: a first‑class `export` subcommand (see SPEC) to write `--json/--yaml` directly to files via `--out`.

## Table and TUI
## Themes

Choose a theme with `--theme NAME` or `FINFOTHEME=NAME`. Available: `default`, `nord`, `dracula`, `solarized`, `synesthesia` (vibrant).

Header layout controls:

```bash
# Left-aligned (default)
export FINFO_HEADER_STYLE=left
# Centered chips
export FINFO_HEADER_STYLE=center
# Optional thin rules under headers
export FINFO_RULE=1
# Clamp header width (default 100)
export FINFO_SECTION_WIDTH=96
```


- Pure zsh compact table:

```bash
source ./finfo.zsh
finfo_table .
```

- Interactive browser (uses fzf + jq when present; falls back to the table):

```bash
source ./finfo.zsh
finfo_browse .
```

- Go TUI (alpha) with split view, action palette, multi-select, status bar, theming, and help overlay:

```bash
cd tui && go build -o finfotui ./...
finfo tui .  # auto-launches if `finfotui` is found
```

Configure theme:

```bash
export FINFOTUI_THEME=default   # or mono|nord|dracula
```

## Install

Quick local install (links `finfo` into `~/bin` and checks environment):

```bash
scripts/install.zsh --all
```

- `--minimal`: install essentials only
- `--all`: also install enhancements (bat, glow, fzf, p7zip, lsof)
- `--check-only`: don’t install; only report environment status
- `--run-tests`: run the golden test harness after install

Planned distribution channels (not implemented here): Homebrew (macOS), Conda (conda-forge), Makefile targets, curl|bash installer, GitHub Releases with checksums.

### Build TUI (optional)

```bash
cd tui
go build -o finfotui ./...
```

Then run:

```bash
finfo tui .
```

It will auto-launch the Go TUI if `finfotui` is on PATH or present in `tui/`, otherwise fall back to the shell TUI.

## Tests

Run the tiny golden test harness (requires `zsh`, JSON tests use `jq` when available):

```bash
./tests/run.zsh
```

- Set `REGEN=1` to regenerate goldens if needed.

## Version

```bash
finfo --version
```

## Examples

```bash
# Pretty output
finfo README.md

# Porcelain (key\tvalue) suitable for awk
finfo --porcelain README.md | column -t -s $'\t'

# JSON + jq
finfo --json README.md | jq .size

# Shortcuts
finfo -C README.md                  # copy absolute path
finfo --open-with "Visual Studio Code" README.md
finfo --copy-hash sha256 README.md  # copy checksum
finfo --chmod 644 README.md         # change perms and confirm

# QR for checksum (requires `qrencode` and a TTY)
finfo --hash sha256 --qr-hash sha256 README.md

# Dashboard
finfo html --dashboard . && open dist/index.html
```

## Shell integration (zsh completions)

Basic zsh completions are provided in `scripts/completions/_finfo`.

Enable by adding this to your `~/.zshrc`:

```zsh
fpath+=("$HOME/path/to/finfo/scripts/completions")
autoload -Uz compinit && compinit
```

Then restart your shell.

## Changelog

See `CHANGELOG.md` for notable changes and versioning policy.
