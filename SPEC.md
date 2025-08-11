# finfo SPEC: Roadmap from "MY OWN THOUGHTS"

## Purpose
Turn the ideas under MY OWN THOUGHTS in `Guess_of_the_Concept` into a pragmatic, phased plan. Keep each step small, shippable, and testable. Favor zsh implementation first (extend `finfo.zsh`), reserving bigger UI for later.

## Design principles
- Small, composable edits; ship value in days, not weeks
- Pretty human output by default; `--porcelain`/`--json` stable for tooling
- macOS-first, graceful cross-platform fallbacks
- No surprises: fast, safe, explain what we infer and why

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

## Next steps (immediate)
1) Phase 1.1: Multi-arg loop in `finfo.zsh` with per-file run and group summary
2) Phase 1.2: Wire `-B` and `-L` flags to existing sections consistently
3) Phase 1.3: Archive quick stats via `zipinfo -t`/`tar -tf | wc -l` (guarded); keep fast
4) Phase 1.4: Script run-hints: extend existing `_action_hints` and `_suggest_quality`
5) Phase 1.5: `--unit` param, unify humanizer

## Risks and mitigations
- Performance on large dirs: cap counts, show “approximate” beyond N entries
- External tools variability: check presence, degrade gracefully
- Portability: keep darwin-specific bits guarded; avoid failing on Linux

