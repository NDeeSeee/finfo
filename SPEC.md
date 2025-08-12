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
  - `--keys` show a KEYS panel at the bottom and accept a single keypress to run a shortcut (TTY-only, default 5s timeout)
  - `--keys-timeout N` override the keypress timeout in seconds (default 5)
  - `--no-keys` suppress auto KEYS panel in `--long` mode
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

Planned new modules (iconic features):
- `_risk.zsh`: Zero‑Trust risk score + provenance graph assembly and rendering
- `_anomaly.zsh`: Temporal/size/anomaly detection primitives and sparklines
- `_summarize.zsh`: Lightweight content summarization (type-aware, opt-in)
- `_tui.zsh`: Interactive navigator (fuzzy search, filters, keybindings)
- `_integrations.zsh`: Glue for `jq`, `yq`, and processor handoffs
- `_sandbox.zsh`: WASM micro‑sandbox harness and behavior capture
- `_attest.zsh`: Sigstore keyless attestation + inferred SBOM-lite
- `_dedupe.zsh`: Near‑duplicate detection (FastCDC + SimHash)
- `_trace.zsh`: eBPF provenance tracer (process↔file↔socket)
- `_redact.zsh`: Multimodal redaction and prompt‑injection checks
- `_dashboard.zsh`: Rich HTML dashboard/static site exporter
- `_index.zsh`: Catalog/SQLite/JSONL indexer and updater

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

### Phase 5 — Iconic features (opt-in, safe-by-default)

1) Zero‑Trust Risk Score + Provenance Graph
- Compute a 0–100 risk score using: Gatekeeper, codesign validity/chain, notarization, quarantine, WhereFroms, executable type, entropy/strings heuristics, permission oddities, first-seen/last-opened recency. Provide a compact “Why” breakdown.
- Render provenance graph (authority → notarization → quarantine → first-seen) inline (ASCII) with flagged edges; add remediation hints.
- CLI: `finfo risk PATH` and `--risk` toggle for normal runs.
- JSON additions: `security.risk_score`, `security.risk_factors[]`, `provenance.graph`.
- Acceptance: deterministic score on same inputs; clear Why list; fast mode uses cached facts; deep mode (`--risk-deep`) enables entropy/strings (guarded).

2) Interactive TUI with Fuzzy Search (fzf-powered)
- Minimal TUI listing targets and drilling into sections; live fuzzy filter by name/type/git status, tabbed sections, theme-aware.
- CLI: `finfo --tui [PATH…]` or `finfo browse DIR`.
- Dependencies optional: prefer builtin navigation; if `fzf` present, enable fuzzy; degrade gracefully.
- Acceptance: smooth navigation on >1K files; exits with selected path; respects `--long`/`--brief`.

3) File Content Summarization (type-aware)
- Generate concise summaries for supported types: Markdown (TOC), CSV/TSV (columns, sample header, delimiter), JSON/YAML (top keys), code (top-level defs), notebooks (kernelspec, cell count), archives (top entries), media (duration/resolution, no decode).
- CLI: `finfo summarize PATH [--lines N]` and `--summary` toggle in pretty output.
- JSON addition: `summary.text` and `summary.highlights[]`.
- Acceptance: runs under 100ms for small files without external heavy deps; gated deep scans.

4) Machine Learning–Based Anomaly Detection (optional)
- Learn typical size/mtime/extension patterns per directory; flag outliers (sudden large binaries in source dirs, future timestamps, burst-edit clusters).
- CLI: `finfo anomalies DIR [--explain]`.
- JSON addition: `anomalies:[{kind, score, explain}]`.
- Acceptance: safe heuristics by default; ML path enabled only with `--ml` and cached per DIR to avoid repeated cost.

5) Integrations with External Tools (processor handoffs)
- First-class pipes to `jq`/`yq`/`dasel` for JSON/YAML, and a stable `--porcelain` schema for trivial `awk`/`sed` tooling.
- CLI sugar: `finfo --json PATH | jq …` examples in docs; `finfo --porcelain | awk -F '\t' …` recipes.
- Acceptance: examples validated in docs/tests; schema stability guaranteed.

6) WASM micro‑sandbox “behavior print”
- Run suspicious scripts/binaries in a Wasmtime/wasmer micro‑VM with seccomp and an eBPF tap; capture FS/DNS/socket/env/syscalls; emit a deterministic behavior signature and safe repro recipe.
- CLI: `finfo run --sandbox PATH [--timeout N]`.
- JSON addition: `behavior: { signature, fs_ops, net_ops, syscalls_sample }`.
- Acceptance: exits safely with bounded time; no side‑effects outside sandbox.

7) Sigstore keyless attestation + inferred SBOM
- Infer a minimal SBOM (langs, deps, toolchain hints), mint a keyless Sigstore attestation (Fulcio/OIDC, Rekor), store alongside artifacts; verify later.
- CLI: `finfo attest PATH…` and `finfo verify PATH…`.
- JSON addition: `attestation: { sigstore: {log_index,…}, sbom: [...] }`.
- Acceptance: offline verify works; logs linkable; graceful when OIDC unavailable.

8) Multimodal redaction + prompt‑injection firewall
- Redact secrets/PII across text, images’ EXIF, Office comments, notebooks; detect prompt‑injection patterns in Markdown/JSON.
- CLI: `finfo scrub PATH [--ai --dry-run]`.
- JSON addition: `redactions:[{type, location, preview}]`, `injection_findings[]`.
- Acceptance: changes are previewable and reversible; no uploads by default.

9) Near‑duplicate radar (FastCDC + SimHash/LSH)
- Detect structure‑preserving clones even after formatting/repack (archives, code); suggest centralization targets and byte‑savings.
- CLI: `finfo similar DIR [--across GIT_ROOT]`.
- JSON addition: `similar_groups:[{rep, members:[{path, sim}] }]`.
- Acceptance: sub‑linear scans with caps; reproducible groups.

10) eBPF live provenance graph
- Temporarily attach eBPF probes during a command to correlate process→file→socket edges; emit a compact provenance graph with critical path and cacheable artifacts.
- CLI: `finfo trace -- cmd …`.
- JSON addition: `provenance.dynamic_graph`.
- Acceptance: requires root/entitlements; no persistent probes; clear tear‑down.

11) Rich HTML Dashboard export + Catalog mode
- Generate a single‑page, aesthetic dashboard (search, filters/facets, sortable tables, in‑page previews, provenance/risk badges). Optionally back by a local catalog (SQLite/JSONL) for cross‑session exploration.
- CLI: `finfo html --dashboard PATH…` (static export) and `finfo catalog --init DIR`, `finfo catalog --update DIR`.
- Artifacts: `dist/index.html`, `dist/assets/*`, `catalog.sqlite|catalog.jsonl`.
- Acceptance: works offline, no trackers; incremental updates; themable.

## Non-goals for now
- Full Bubble Tea TUI; deep provenance timelines; AI summaries; heavy scanners
- Exception: Phase 5 introduces opt-in, lightweight versions of risk scoring, summarization, and anomaly detection with strict guardrails and caching.
- Long-running background daemons; intrusive system changes

## Data model (JSON additions planned)
- `group_summary`: `{ total, by_type: [{ext, count, size_bytes_max, size_bytes_sum}], oldest, largest }`
- `monitor`: `{ trend: grow|shrink|flat, rate_bytes_per_s, window_seconds }`
- `links`: `{ symlink: {target, exists}, hardlink_count }`
- `proc`: `{ open_handles: [{pid, name}] }`
- `filetype`: `{ kind, stats: {pages|rows|cols|headings|delimiter} }`
- `security.risk_score`: `0..100` with higher meaning riskier
- `security.risk_factors[]`: `[{key, weight, evidence}]`
- `provenance.graph`: collapsed adjacency list with labels and flags
- `summary`: `{ text, highlights: [{label, value}] }`
- `anomalies[]`: `[{kind, score, explain}]`
- `behavior`: `{ signature, fs_ops, net_ops, syscalls_sample }`
- `attestation`: `{ sigstore: {log_index,…}, sbom: [ {name, version, type} ] }`
- `redactions[]`: `[{type, location, preview}]`
- `similar_groups[]`: `[{rep, members:[{path, sim}]}]`
- `provenance.dynamic_graph`: collapsed adjacency for eBPF trace
- `catalog`: `{ entry_id, index_time, source_root }`

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
13) Phase 1.13: Move subcommands into `lib/cmd/` directory [DONE]
14) Phase 1.14: Add docs/ with JSON schema and examples; tests/ with golden outputs [IN PROGRESS]
15) Phase 1.15: KEYS panel and shortcut actions (`--keys`, `--keys-timeout`, `--no-keys`; auto in `--long`) [DONE]
16) Phase 5 scaffolding: add module stubs `_risk.zsh`, `_summarize.zsh`, `_anomaly.zsh`, `_tui.zsh`, `_dashboard.zsh`, `_index.zsh`, `_dedupe.zsh`, `_attest.zsh`, `_sandbox.zsh`, `_trace.zsh`, `_redact.zsh` (lazy‑loaded) and extend JSON schema [PLANNED]

## Risks and mitigations
- Performance on large dirs: cap counts, show “approximate” beyond N entries
- External tools variability: check presence, degrade gracefully
- Portability: keep darwin-specific bits guarded; avoid failing on Linux
 - Modular bloat: keep modules focused, small, and composable; avoid cross-coupling; document module contracts in `docs/`

