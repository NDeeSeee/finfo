# finfo

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
      [--keys|--no-keys] [--keys-timeout N] PATH...

finfo diff A B             # metadata diff (porcelain-based)
finfo chmod PATH           # interactive chmod helper (arrows/space/s/q)
finfo watch PATH [secs]    # live sample size/mtime/quarantine changes
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

## Dependencies

See `dependencies/README.md` for essential and optional tools (install commands for macOS and Linux), fonts, and environment variables. finfo degrades gracefully when extras are missing.

## Tests

Run the tiny golden test harness (requires `zsh`, JSON tests use `jq` when available):

```bash
./tests/run.zsh
```
