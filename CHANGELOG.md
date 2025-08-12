# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to Semantic Versioning (SemVer) once versioned.

## [Unreleased]
### Added
- Shortcut flags: `--copy-path/-C`, `--open/-O`, `--open-with APP`, `--reveal/-E`, `--edit APP/-e`, `--copy-rel`, `--copy-dir`, `--copy-hash ALGO`, `--chmod OCTAL`, `--clear-quarantine/-Q`
- KEYS panel (`--keys`, `--keys-timeout`, `--no-keys`); auto-enabled by `--long`
- Installer script `scripts/install.zsh`; dependencies guide; macOS CI
- Test harness with porcelain/JSON goldens; HTML and monitor/zip smokes
- `--risk` (-S) JSON stub (flag-gated)
- `finfo html --dashboard` exporter
- Go TUI (alpha) in `tui/` using Bubble Tea + Bubbles + Lip Gloss; `finfo tui` forwards to `finfotui` binary when present (shell fallback otherwise)

### Changed
- Modularized codebase under `lib/`, subcommands under `lib/cmd/`
- README updates: Install, Dependencies, Examples, Completions, CI badge

### Removed
- Legacy subcommand fallback in `_cmd_loader.zsh`

## [0.1.0] - 2025-08-12
- Initial structured release (to be tagged). Includes core finfo functionality and documentation.
