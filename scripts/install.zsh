#!/usr/bin/env zsh
# finfo installer — sets up dependencies and a convenient CLI entrypoint
# Usage:
#   scripts/install.zsh [--minimal|--all] [--check-only] [--run-tests]
# Notes:
# - macOS-first; Linux best-effort (Debian/Ubuntu assumed). Others: prints guidance.
# - This script installs ESSENTIAL tools by default; pass --all to add enhancements.
# - Packaging tracks to publish later (not implemented here):
#   * Homebrew formula (tap) for macOS
#   * Conda package (conda-forge)
#   * Makefile targets (make install/uninstall)
#   * Git-based install (curl | bash or git clone + bin shim)
#   * Release artifacts (GitHub releases) with checksums

set -euo pipefail

# Colors (respect NO_COLOR)
if [[ -n ${NO_COLOR:-} ]]; then BOLD="" DIM="" RESET="" GREEN="" YELLOW="" BLUE="" CYAN=""; else
  BOLD="\033[1m"; DIM="\033[2m"; RESET="\033[0m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[34m"; CYAN="\033[36m";
fi

want_all=0; check_only=0; run_tests=0
for arg in "$@"; do
  case "$arg" in
    --all) want_all=1;;
    --minimal) want_all=0;;
    --check-only) check_only=1;;
    --run-tests) run_tests=1;;
    *) echo "${YELLOW}WARN${RESET}: unknown arg '$arg'" >&2 ;;
  esac
done

script_dir=${0:A:h}
repo_root=${script_dir:h}
cli_src="$repo_root/finfo.zsh"

print_h() { printf "%s\n" "$*"; }
print_s() { printf "${GREEN}✔${RESET} %s\n" "$*"; }
print_w() { printf "${YELLOW}•${RESET} %s\n" "$*"; }

is_cmd() { command -v "$1" >/dev/null 2>&1; }

mac_install() {
  local -a essentials=( jq unzip )
  local -a extras=( p7zip lsof bat glow fzf )
  if ! is_cmd brew; then
    print_w "Homebrew not found. Install from https://brew.sh and re-run for automatic dependency install."
    return 0
  fi
  print_h "${BOLD}Installing essentials via Homebrew...${RESET}"
  brew update
  for f in ${essentials[@]}; do brew list "$f" >/dev/null 2>&1 || brew install "$f" || true; done
  if (( want_all )); then
    print_h "${BOLD}Installing additional tools via Homebrew...${RESET}"
    for f in ${extras[@]}; do brew list "$f" >/dev/null 2>&1 || brew install "$f" || true; done
  fi
}

linux_install() {
  if ! is_cmd apt-get; then
    print_w "Non-Debian-based Linux detected. Please install: jq unzip tar file (essentials); optional: p7zip-full lsof bat glow fzf (extras)."
    return 0
  fi
  sudo apt-get update
  print_h "${BOLD}Installing essentials via apt...${RESET}"
  sudo apt-get install -y jq unzip tar file || true
  if (( want_all )); then
    print_h "${BOLD}Installing additional tools via apt...${RESET}"
    sudo apt-get install -y p7zip-full lsof fzf || true
    # bat/glow may be named differently depending on distro
    sudo apt-get install -y bat || true
    sudo apt-get install -y glow || true
  fi
  # Clipboard utils
  if (( want_all )); then
    sudo apt-get install -y wl-clipboard xclip || true
  fi
}

link_cli() {
  local bindir="$HOME/bin"
  mkdir -p "$bindir"
  local target="$bindir/finfo"
  ln -sf "$cli_src" "$target"
  chmod +x "$cli_src" "$target" || true
  print_s "Linked CLI: ${CYAN}$target${RESET} -> ${CYAN}$cli_src${RESET}"
  case ":$PATH:" in
    *":$bindir:"*) ;;
    *) print_w "Add ${CYAN}export PATH=\"$bindir:\$PATH\"${RESET} to your shell rc (e.g., ~/.zshrc)" ;;
  esac
}

checks() {
  print_h "${BOLD}Environment checks${RESET}"
  is_cmd zsh && print_s "zsh present" || print_w "zsh missing"
  is_cmd jq && print_s "jq present" || print_w "jq missing (JSON tests/features limited)"
  is_cmd unzip && print_s "unzip/zipinfo present" || print_w "unzip missing (archive stats limited)"
  if [[ $OSTYPE == darwin* ]]; then
    is_cmd mdls && print_s "Spotlight (mdls) present" || print_w "mdls missing (unexpected on macOS)"
    is_cmd sips && print_s "sips present" || print_w "sips missing (unexpected on macOS)"
    is_cmd pbcopy && print_s "clipboard (pbcopy) present" || print_w "pbcopy missing"
  else
    (is_cmd wl-copy || is_cmd xclip) && print_s "clipboard utility present" || print_w "install wl-clipboard or xclip for copy actions"
  fi
}

main() {
  print_h "${BOLD}finfo installer${RESET}"
  if (( check_only )); then
    checks; return 0
  fi
  case "$OSTYPE" in
    darwin*) mac_install;;
    linux*) linux_install;;
    *) print_w "Unsupported OS signature '$OSTYPE'. Proceeding with checks and link only." ;;
  esac
  link_cli
  checks
  print_h "${BOLD}Packaging tracks (not implemented in this script)${RESET}"
  print_w "Homebrew formula (tap): build and publish a formula for finfo"
  print_w "Conda package: publish to conda-forge"
  print_w "Makefile: make install/uninstall targets"
  print_w "Git-based: curl | bash installer and git clone instructions"
  print_w "Release artifacts: attach tarballs/zips with checksums to GitHub releases"
  if (( run_tests )); then
    if [[ -x "$repo_root/tests/run.zsh" ]]; then
      print_h "${BOLD}Running tests...${RESET}"
      (cd "$repo_root" && ./tests/run.zsh) || true
    else
      print_w "tests/run.zsh not found or not executable"
    fi
  fi
  print_h "${BOLD}${GREEN}Done.${RESET} Restart your shell or reload rc to pick up PATH changes."
}

main "$@"
