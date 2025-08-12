# finfo SPEC: Roadmap from "MY OWN THOUGHTS"

## Purpose
Turn the ideas under MY OWN THOUGHTS in `Guess_of_the_Concept` into a pragmatic, phased plan. Keep each step small, shippable, and testable. Favor zsh implementation first (extend `finfo.zsh`), reserving bigger UI for later.
## Consolidated concept (from Guess_of_the_Concept)

High-level MVP and differentiators:
- CLI + Header: file name, type, size, lines, workflow version hint (CWL/WDL), git snippet
- Pretty sections: Essentials (MIME/UTType, owner/group, perms), Timeline, Paths, Security (verdict, gatekeeper/codesign/notarization/quarantine/WhereFroms), Creator fields
- Interactive inspector (future): list + detail panel, keybindings, theme presets
- Viral add-on: inline thumbnails (Kitty/iTerm2 protocols) with graceful fallbacks
- Diff & HTML: `finfo diff A B` and `--html` report

Design system:
- Accent hue per theme; labels 12ch left-aligned; icons in headers only; accessibility-conscious; TrueColor → 256 → mono fallback

Security/provenance (macOS):
- Gatekeeper (spctl --assess), codesign identity/validity, notarization staple/state, quarantine decode (agent/epoch/flags), WhereFroms, (optional) provenance xattr summary

Extended ideas (shortlist):
- Media-aware inline summaries (resolution/duration/EXIF/page count)
- Arithmetic/conversion smart fields (size units, time formats)
- Copy-friendly values (hashes, paths, verdict)
- Contextual fix prompts (clear quarantine, open in Finder, codesign hints)
- Smart group summaries (by type: counts, largest/oldest, trust flags)
- Visionary relationships (APFS clones, hard links, duplicates, symlinks)
- Provenance timeline (WhereFroms + quarantine + provenance)
- Natural-language querying (future)
- Templates for known types (Dockerfile base image/layers; MD TOC; CSV stats)

Why these matter: reduce cognitive load; surface context; be actionable; create screenshot-worthy moments.


## Design principles
- Small, composable edits; ship value in days, not weeks
- Pretty human output by default; `--porcelain`/`--json` stable for tooling
- macOS-first, graceful cross-platform fallbacks
- No surprises: fast, safe, explain what we infer and why
- Keep `finfo.zsh` minimal; delegate logic to focused modules in `lib/` and subcommands in `lib/cmd/`

## CLI surface (additions)
- `finfo [FILES|DIRS…]` multi-arg support (iterate in given order)
- Modes and toggles
  - `-B, --brief` concise sections only
  - `-L, --long` expanded sections (filetype-aware extras)
  - `-i, --interactive` enter basic navigator (stub v1)
  - `-m, --monitor` watch size/xattrs/trust briefly and summarize deltas
  - `--duplicates` check digest across a search root
  - `--open-with APP` suggest or open via `open -a APP` (darwin)
  - `--unit bytes|iec|si` size unit preference for display
- Output
  - Pretty: sections; Porcelain: key\tvalue; JSON: stable schema

## Architecture and directory layout

- `finfo.zsh`: Orchestrator only (parse flags, gather core facts, delegate)
- `lib/`
  - `_colors.zsh`, `_icons.zsh`, `_format.zsh`, `_size.zsh`, `_sections.zsh`, `_actions.zsh`
  - `_security.zsh`: Gatekeeper/codesign/notarization/quarantine/where_froms/verdict
  - `_filetype.zsh`: PDF pages, Markdown headings, CSV columns/delimiter, image WxH, media duration, About
  - `_summary.zsh`: Multi-target SUMMARY block
  - `_checksum.zsh`: Checksum computation
  - `_monitor.zsh`: Size-rate computation over a window
  - `_html.zsh`: HTML report generator
  - `_git.zsh`: Git metadata helper
  - `_config.zsh`: Loads env defaults and optional $HOME/.config/finfo/config.zsh
  - `cmd_*.zsh` (currently in `lib/`, next step: move under `lib/cmd/`):
    - `cmd_diff.zsh`, `cmd_watch.zsh`, `cmd_chmod.zsh`, `cmd_duplicates.zsh`

Proposed near-term reorganizations:
- Create `lib/cmd/` to host all subcommands; update sources accordingly
- Add `docs/` for schema and developer notes; add `tests/` for golden outputs
- Optional: `examples/` with sample invocations; `scripts/` for install/update helpers

## Feature backlog mapped to phases

### Phase 1 — Simple, high-ROI (zsh-only)
1) Multi-file and directory handling
- Iterate over multiple paths
- Group summary when inputs > 1: counts per type, largest/oldest, trust-flags
- Acceptance: `finfo A B/ C` prints per-item + one group summary

2) Brief/Long refinements
- Wire `-B` to hide Timeline/Paths/Security extras
- Wire `-L` to show extras (filetype-aware hints where available)
- Acceptance: toggles change section visibility deterministically

3) Script run-hints and openers
- For scripts and notebooks, show “how to run” hints; ensure Finder/app openers present
- Acceptance: `.py` shows `python3 file.py`; `open` always offered on macOS

4) Archive quick stats
- Detect archive by content; show contained count (fast) and extraction hint
- Acceptance: `.zip` shows file count and `unzip` line if content matches

5) Size unit preference
- `--unit` to force bytes/IEC/SI; porcelain/json always include `size_bytes`
- Acceptance: human display respects chosen unit scheme

### Phase 2 — Medium complexity
6) File growth/operation awareness
- `--monitor` samples size at short intervals (e.g., 3 samples / 2s) and reports trend (grow/shrink, rate)
- If quarantine present and file just appeared, hint “likely download”
- Acceptance: shows rate like `+1.2 MB/s (~3s window)` when growing

7) Duplicates and linked files
- For given path(s), compute digest (configurable algo) and scan within project tree for duplicates (by content)
- Show symlink/hardlink info
- Acceptance: prints duplicates list, marks hard/sym links distinctly

8) Process interaction
- Best-effort: detect if a file is opened by a process (darwin `lsof`), show top 3 matches
- Acceptance: `.log` shows `tail`/`app` holding the file when applicable

### Phase 3 — Interaction and permissions
9) Interactive stub (`-i`)
- Minimal list + detail pane in pure shell (no TUI libs): j/k to move, Enter to show actions, q to quit
- Acceptance: basic navigator over provided items

10) Permissions assist
- Explain `chmod` values; offer one-liners (not auto-run) to change bits
- Acceptance: concise explain string + suggested commands

### Phase 4 — Filetype extras and conversions
11) Filetype-specific stats
- PDFs: pages; Markdown: headings count; CSV/TSV: rows/cols + delimiter guess
- Acceptance: each prints a small, fast stat without heavy deps

12) Lightweight conversions
- Safe shell wrappers for common conversions (expose suggested commands only)
- Acceptance: e.g., `pdf → png` suggestion if `pdftoppm` exists; JSON↔YAML if tools present

13) Notes / QuickActions
- Per-path local notes (sidecar `.finfo.notes`), and a few quick action templates
- Acceptance: `--notes` shows first line and a count of notes

## Non-goals for now
- Full Bubble Tea TUI; deep provenance timelines; AI summaries; heavy scanners
- Long-running background daemons; intrusive system changes

## Data model (JSON additions planned)
- `group_summary`: `{ total, by_type: [{ext, count, size_bytes_max, size_bytes_sum}], oldest, largest }`
- `monitor`: `{ trend: grow|shrink|flat, rate_bytes_per_s, window_seconds }`
- `links`: `{ symlink: {target, exists}, hardlink_count }`
- `proc`: `{ open_handles: [{pid, name}] }`
- `filetype`: `{ kind, stats: {pages|rows|cols|headings|delimiter} }`

## Testing
- Golden outputs for porcelain/json for: text file, archive, dir (small), Mach-O, symlink
- Smoke tests for multi-file, brief/long toggles, archive detection, growth monitor (simulate via temp writes)
 - Add tests for security JSON block, About field, quick stats

## Next steps (immediate)
1) Phase 1.1: Multi-arg loop in `finfo.zsh` with per-file run and group summary [DONE]
2) Phase 1.2: Wire `-B` and `-L` flags to existing sections consistently
3) Phase 1.3: Archive quick stats via `zipinfo -t`/`tar -tf | wc -l` (guarded); keep fast [DONE]
4) Phase 1.4: Script run-hints: extend existing `_action_hints` and `_suggest_quality` [DONE]
5) Phase 1.5: `--unit` param, unify humanizer [DONE]
6) Phase 1.6: `--monitor` lightweight file growth/shrink rate with configurable window [DONE]
7) Phase 1.7: `--duplicates` content duplicate groups (sha256) with cap [DONE]
8) Phase 1.8: Security JSON/porcelain fields (gatekeeper/codesign/notarization/quarantine/where_froms/verdict) [DONE]
9) Phase 1.9: About line in pretty/porcelain/JSON [DONE]
10) Phase 1.10: Subcommands `diff`, `chmod`, `watch` [DONE]
11) Phase 1.11: `--html` minimal report [DONE]
12) Phase 1.12: Modularization into `lib/` helpers and `lib/cmd/` subcommands [DONE]
13) Phase 1.13: Move subcommands into `lib/cmd/` directory [NEXT]
14) Phase 1.14: Add docs/ with JSON schema and examples; tests/ with golden outputs [NEXT]

## Risks and mitigations
- Performance on large dirs: cap counts, show “approximate” beyond N entries
- External tools variability: check presence, degrade gracefully
- Portability: keep darwin-specific bits guarded; avoid failing on Linux
 - Modular bloat: keep modules focused, small, and composable; avoid cross-coupling; document module contracts in `docs/`

