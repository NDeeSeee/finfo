# finfo dependencies

This project is macOS‑first, with graceful cross‑platform fallbacks. Below are the tools the CLI relies on or can optionally use to enhance output, speed, or UX.

## Essential (runtime)

These are either built‑in on macOS or widely available on Linux. finfo will degrade gracefully when something is missing.

- Shell/runtime
  - zsh 5.8+ (macOS ships with zsh)
  - POSIX utilities: `stat`, `file`, `wc`, `awk`, `sed`, `tar`, `du`, `ls`
- macOS integrations (built‑in on macOS):
  - Spotlight metadata: `mdls`
  - Images: `sips`
  - Security: `spctl`, `codesign`, `stapler`, `xattr`
- Archives (fast stats and hints):
  - zip: `unzip` (provides `zipinfo`)
  - tar variants: `tar`

### Install (macOS)

```bash
# Install Homebrew if needed: https://brew.sh
brew install unzip gnu-tar
```

Note: macOS already provides `file`, `tar`, `mdls`, `sips`, `spctl`, `codesign`, `stapler`, `xattr`.

### Install (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y zsh file tar unzip p7zip-full
```

Clipboard (Linux):

```bash
# Wayland
sudo apt-get install -y wl-clipboard
# X11
sudo apt-get install -y xclip
```

## Additional (enhancements)

Install these to unlock richer output, nicer UX, or developer convenience. finfo detects and uses them when present.

- JSON/YAML processors: `jq`, `yq`
  - macOS: `brew install jq yq`
  - Debian/Ubuntu: `sudo apt-get install -y jq` (yq via snap/pip/pkg)
- Viewers and editors (used for action hints): `bat`, `glow`, `code`, `subl`, `cursor`
  - macOS: `brew install bat glow`
  - Debian/Ubuntu: `sudo apt-get install -y bat` (or `batcat`), `glow`
- Duplicates and archives: `p7zip` (`7z`)
  - macOS: `brew install p7zip`
  - Debian/Ubuntu: `sudo apt-get install -y p7zip-full`
- Open handles (verbose): `lsof`
  - macOS: already present; Debian/Ubuntu: `sudo apt-get install -y lsof`
- Fonts (icons in headers/sections): Nerd Fonts (e.g., Hack Nerd Font)
  - Download from https://www.nerdfonts.com and enable in your terminal profile
  - Optional: export `FINFONERD=1` to force icon mode
- Fuzzy picker and interactive TUI: `fzf`
  - macOS: `brew install fzf`
  - Debian/Ubuntu: `sudo apt-get install -y fzf`
- JSON processor: `jq`
  - macOS: `brew install jq`
  - Debian/Ubuntu: `sudo apt-get install -y jq`
- Fast file search (preferred): `fd`
  - macOS: `brew install fd`
  - Debian/Ubuntu: `sudo apt-get install -y fd-find` (alias: `alias fd=fdfind`)
- Fast code/text search: `ripgrep` (`rg`)
  - macOS: `brew install ripgrep`
  - Debian/Ubuntu: `sudo apt-get install -y ripgrep`
- Visual scripting aids (optional): `gum`
  - macOS: `brew install gum`
  - Debian/Ubuntu: `sudo apt-get install -y gum` (or from project releases)
- Prompt/theme comfort (optional): Powerlevel10k
  - Repo: https://github.com/romkatv/powerlevel10k
  - Install: `git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k`
  - Enable in `~/.zshrc`: `ZSH_THEME="powerlevel10k/powerlevel10k"`
- zsh plugins (optional):
  - zsh-syntax-highlighting: https://github.com/zsh-users/zsh-syntax-highlighting
  - zsh-autosuggestions: https://github.com/zsh-users/zsh-autosuggestions
  - Enable via `plugins=(... zsh-syntax-highlighting zsh-autosuggestions)` in `~/.zshrc`

## Shell completions (zsh)

Basic completions are provided at `scripts/completions/_finfo`.

Enable by adding to your `~/.zshrc`:

```zsh
fpath+=("$HOME/path/to/finfo/scripts/completions")
autoload -Uz compinit && compinit
```

## Developer/test dependencies

- Test harness (JSON goldens): `jq`
  - macOS: `brew install jq`
  - Debian/Ubuntu: `sudo apt-get install -y jq`

Run tests:

```bash
./tests/run.zsh
```

## Environment variables

- `FINFOTHEME`: select theme (e.g., `default`)
- `FINFO_UNIT`: size unit scheme for human display (`bytes|iec|si`)
- `FINFO_TOPN`: number of Top‑N entries in SUMMARY (default 5)
- `FINFONERD`: set to `1` to enable Nerd Font icons when available
- `FINFOCODE`: set to `1` to include code‑style path tags
- `NO_COLOR`: disable colors in output
- `FINFO_CLIPBOARD_MODE=stdout`: print copied content to stdout instead of using clipboard utilities

## Notes

- finfo checks for tool presence at runtime and degrades gracefully.
- On Linux, macOS‑specific fields (Gatekeeper, Codesign, Notarization, Quarantine) are shown as `unknown`.
- For best visuals, use a terminal with TrueColor and a Nerd Font.
